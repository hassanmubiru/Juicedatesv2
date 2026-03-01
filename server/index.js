/**
 * JuiceDates Notification Server
 * Runs on Render.com free tier — replaces Firebase Cloud Functions.
 *
 * Required environment variables (set in Render dashboard):
 *   FIREBASE_SERVICE_ACCOUNT  — Full JSON content of your Firebase service account key
 *   NOTIFY_API_KEY            — A secret string your Flutter app must include in every request
 *   PORT                      — Set automatically by Render (default 10000)
 */

const express = require('express');
const admin   = require('firebase-admin');

// ─── Init ─────────────────────────────────────────────────────────────────────

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db        = admin.firestore();
const messaging = admin.messaging();
const app       = express();
app.use(express.json());

const API_KEY = process.env.NOTIFY_API_KEY || 'juice-dev-key';
const PORT    = process.env.PORT || 10000;

// ─── Auth middleware ──────────────────────────────────────────────────────────

function requireKey(req, res, next) {
  if (req.headers['x-api-key'] !== API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function getToken(uid) {
  const doc = await db.collection('users').doc(uid).get();
  return doc.data()?.fcmToken ?? null;
}

async function sendTo(token, title, body, data = {}) {
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
  } catch (err) {
    // Invalid / stale token — not a fatal error
    console.warn('FCM sendTo failed:', token, err?.message);
  }
}

// ─── Endpoints ────────────────────────────────────────────────────────────────

// Health check (Render pings this)
app.get('/', (_, res) => res.json({ status: 'ok', service: 'JuiceDates Notify' }));

/**
 * POST /api/notify/match
 * Body: { uid1, uid2, name1, name2, matchId, sparksScore }
 * Notifies both users of a new match.
 */
app.post('/api/notify/match', requireKey, async (req, res) => {
  const { uid1, uid2, name1, name2, matchId, sparksScore } = req.body;
  if (!uid1 || !uid2) return res.status(400).json({ error: 'uid1 and uid2 required' });

  const [token1, token2] = await Promise.all([getToken(uid1), getToken(uid2)]);
  const sparks = Math.round(sparksScore ?? 0);

  const sends = [];
  if (token1) sends.push(sendTo(token1,
    '🎉 It\'s a Juice Match!',
    `You and ${name2 ?? 'someone'} matched — ${sparks}% Sparks!`,
    { type: 'match', matchId: matchId ?? '', partnerUid: uid2 }
  ));
  if (token2) sends.push(sendTo(token2,
    '🎉 It\'s a Juice Match!',
    `You and ${name1 ?? 'someone'} matched — ${sparks}% Sparks!`,
    { type: 'match', matchId: matchId ?? '', partnerUid: uid1 }
  ));

  await Promise.all(sends);
  console.log(`[match] ${uid1} ↔ ${uid2} notified`);
  res.json({ sent: sends.length });
});

/**
 * POST /api/notify/message
 * Body: { matchId, senderUid, senderName, recipientUid, text }
 * Notifies the recipient of a new chat message.
 */
app.post('/api/notify/message', requireKey, async (req, res) => {
  const { senderUid, senderName, recipientUid, matchId, text } = req.body;
  if (!recipientUid || !senderUid) return res.status(400).json({ error: 'recipientUid and senderUid required' });

  const token = await getToken(recipientUid);
  if (token) {
    const preview = (text ?? '').length > 80 ? text.substring(0, 80) + '…' : (text ?? '📎 Media');
    await sendTo(token, senderName ?? 'Your match', preview,
      { type: 'message', matchId: matchId ?? '', senderUid }
    );
    console.log(`[message] ${senderUid} → ${recipientUid}`);
  }

  res.json({ sent: token ? 1 : 0 });
});

/**
 * POST /api/notify/announcement
 * Body: { title, body }
 * Broadcasts to the "all_users" FCM topic.
 */
app.post('/api/notify/announcement', requireKey, async (req, res) => {
  const { title, body } = req.body;
  if (!body) return res.status(400).json({ error: 'body required' });

  await messaging.send({
    topic: 'all_users',
    notification: { title: title ?? 'JuiceDates', body },
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  });

  console.log(`[announcement] "${title}" broadcast sent`);
  res.json({ sent: true });
});

/**
 * POST /api/notify/ban
 * Body: { uid, displayName }
 * Deletes all matches for the banned user and notifies admins.
 */
app.post('/api/notify/ban', requireKey, async (req, res) => {
  const { uid, displayName } = req.body;
  if (!uid) return res.status(400).json({ error: 'uid required' });

  // Delete matches + sub-collections
  const matchesSnap = await db.collection('matches')
    .where('users', 'array-contains', uid)
    .get();

  const deleteOps = matchesSnap.docs.map(async (matchDoc) => {
    const msgsSnap = await matchDoc.ref.collection('messages').get();
    await Promise.all(msgsSnap.docs.map(m => m.ref.delete()));
    return matchDoc.ref.delete();
  });
  await Promise.all(deleteOps);

  // Notify admins
  try {
    await messaging.send({
      topic: 'admins',
      notification: {
        title: 'User Banned',
        body: `${displayName ?? uid} banned. ${matchesSnap.size} matches removed.`,
      },
      data: { type: 'ban', uid },
    });
  } catch (_) { /* no admins subscribed yet */ }

  console.log(`[ban] ${displayName ?? uid} — ${matchesSnap.size} matches deleted`);
  res.json({ matchesDeleted: matchesSnap.size });
});

// ─── Start ────────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`JuiceDates notify server running on port ${PORT}`);
});
