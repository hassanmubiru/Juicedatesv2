import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Fetch the FCM token for a user. Returns null if not set. */
async function getToken(uid: string): Promise<string | null> {
  const doc = await db.collection("users").doc(uid).get();
  return (doc.data()?.fcmToken as string) ?? null;
}

/** Send a push notification to a single FCM token. Silently ignores invalid tokens. */
async function sendTo(
  token: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data,
      android: { priority: "high" },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    });
  } catch (err: unknown) {
    // Token invalid / app uninstalled — ignore
    functions.logger.warn("FCM send failed", { token, err });
  }
}

// ─── 1. Match Created ─────────────────────────────────────────────────────────
// Fires when a new document appears in /matches/{matchId}
// Notifies both users that they have a new Juice match.

export const onMatchCreated = functions.firestore.onDocumentCreated(
  "matches/{matchId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const users: string[] = data.users ?? [];
    const userNames: Record<string, string> = data.userNames ?? {};
    const sparksScore: number = data.sparksScore ?? 0;

    if (users.length < 2) return;

    const [uid1, uid2] = users;
    const [token1, token2] = await Promise.all([getToken(uid1), getToken(uid2)]);

    const sparks = sparksScore.toFixed(0);

    const sends: Promise<void>[] = [];
    if (token1) {
      sends.push(
        sendTo(
          token1,
          "🎉 It's a Juice Match!",
          `You and ${userNames[uid2] ?? "someone"} matched — ${sparks}% Sparks!`,
          { type: "match", matchId: event.params.matchId, partnerUid: uid2 }
        )
      );
    }
    if (token2) {
      sends.push(
        sendTo(
          token2,
          "🎉 It's a Juice Match!",
          `You and ${userNames[uid1] ?? "someone"} matched — ${sparks}% Sparks!`,
          { type: "match", matchId: event.params.matchId, partnerUid: uid1 }
        )
      );
    }
    await Promise.all(sends);
  }
);

// ─── 2. New Message ───────────────────────────────────────────────────────────
// Fires when a new message is added to /matches/{matchId}/messages/{messageId}
// Pushes a notification to the other participant.

export const onNewMessage = functions.firestore.onDocumentCreated(
  "matches/{matchId}/messages/{messageId}",
  async (event) => {
    const msgData = event.data?.data();
    if (!msgData) return;

    const senderId: string = msgData.senderId ?? "";
    const text: string = msgData.text ?? "";

    // Get match doc to find the recipient
    const matchDoc = await db
      .collection("matches")
      .doc(event.params.matchId)
      .get();
    const matchData = matchDoc.data();
    if (!matchData) return;

    const users: string[] = matchData.users ?? [];
    const recipientUid = users.find((u) => u !== senderId);
    if (!recipientUid) return;

    const userNames: Record<string, string> = matchData.userNames ?? {};
    const senderName = userNames[senderId] ?? "Your match";

    const token = await getToken(recipientUid);
    if (!token) return;

    await sendTo(
      token,
      senderName,
      text.length > 80 ? text.substring(0, 80) + "…" : text,
      {
        type: "message",
        matchId: event.params.matchId,
        senderUid: senderId,
      }
    );
  }
);

// ─── 3. Announcement Broadcast ────────────────────────────────────────────────
// Fires when an admin writes to /announcements/{id}
// Sends the announcement to the "all_users" FCM topic.
// Users are subscribed to this topic when they open the app (see Flutter client).

export const onAnnouncementCreated = functions.firestore.onDocumentCreated(
  "announcements/{announcementId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const title: string = data.title ?? "JuiceDates";
    const body: string = data.body ?? "";

    if (!body) return;

    await messaging.send({
      topic: "all_users",
      notification: { title, body },
      android: { priority: "high" },
      apns: {
        payload: { aps: { sound: "default" } },
      },
    });

    functions.logger.info("Announcement broadcast sent", { title });
  }
);

// ─── 4. User Banned — Cleanup ─────────────────────────────────────────────────
// Fires when a user document is updated.
// If isBanned flipped to true: deletes all their active matches and notifies admins.

export const onUserBanned = functions.firestore.onDocumentUpdated(
  "users/{uid}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const wasBanned: boolean = before.isBanned ?? false;
    const nowBanned: boolean = after.isBanned ?? false;

    // Only act when isBanned flips from false → true
    if (wasBanned || !nowBanned) return;

    const uid: string = event.params.uid;
    const displayName: string = after.displayName ?? uid;

    functions.logger.info(`User banned: ${displayName} (${uid})`);

    // Delete all matches involving this user
    const matchesSnap = await db
      .collection("matches")
      .where("users", "array-contains", uid)
      .get();

    const deleteOps = matchesSnap.docs.map(async (matchDoc) => {
      // Delete sub-collection messages first
      const msgsSnap = await matchDoc.ref.collection("messages").get();
      const msgDeletes = msgsSnap.docs.map((m) => m.ref.delete());
      await Promise.all(msgDeletes);
      return matchDoc.ref.delete();
    });

    await Promise.all(deleteOps);
    functions.logger.info(
      `Deleted ${matchesSnap.size} matches for banned user ${uid}`
    );

    // Notify admins via the "admins" FCM topic
    try {
      await messaging.send({
        topic: "admins",
        notification: {
          title: "User Banned",
          body: `${displayName} has been banned. ${matchesSnap.size} matches removed.`,
        },
        data: { type: "ban", uid },
      });
    } catch (_) {
      // No admins subscribed yet — safe to ignore
    }
  }
);
