"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onUserBanned = exports.onAnnouncementCreated = exports.onNewMessage = exports.onMatchCreated = void 0;
const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
// ─── Helpers ──────────────────────────────────────────────────────────────────
/** Fetch the FCM token for a user. Returns null if not set. */
async function getToken(uid) {
    var _a, _b;
    const doc = await db.collection("users").doc(uid).get();
    return (_b = (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken) !== null && _b !== void 0 ? _b : null;
}
/** Send a push notification to a single FCM token. Silently ignores invalid tokens. */
async function sendTo(token, title, body, data = {}) {
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
    }
    catch (err) {
        // Token invalid / app uninstalled — ignore
        functions.logger.warn("FCM send failed", { token, err });
    }
}
// ─── 1. Match Created ─────────────────────────────────────────────────────────
// Fires when a new document appears in /matches/{matchId}
// Notifies both users that they have a new Juice match.
exports.onMatchCreated = functions.firestore.onDocumentCreated("matches/{matchId}", async (event) => {
    var _a, _b, _c, _d, _e, _f;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const users = (_b = data.users) !== null && _b !== void 0 ? _b : [];
    const userNames = (_c = data.userNames) !== null && _c !== void 0 ? _c : {};
    const sparksScore = (_d = data.sparksScore) !== null && _d !== void 0 ? _d : 0;
    if (users.length < 2)
        return;
    const [uid1, uid2] = users;
    const [token1, token2] = await Promise.all([getToken(uid1), getToken(uid2)]);
    const sparks = sparksScore.toFixed(0);
    const sends = [];
    if (token1) {
        sends.push(sendTo(token1, "🎉 It's a Juice Match!", `You and ${(_e = userNames[uid2]) !== null && _e !== void 0 ? _e : "someone"} matched — ${sparks}% Sparks!`, { type: "match", matchId: event.params.matchId, partnerUid: uid2 }));
    }
    if (token2) {
        sends.push(sendTo(token2, "🎉 It's a Juice Match!", `You and ${(_f = userNames[uid1]) !== null && _f !== void 0 ? _f : "someone"} matched — ${sparks}% Sparks!`, { type: "match", matchId: event.params.matchId, partnerUid: uid1 }));
    }
    await Promise.all(sends);
});
// ─── 2. New Message ───────────────────────────────────────────────────────────
// Fires when a new message is added to /matches/{matchId}/messages/{messageId}
// Pushes a notification to the other participant.
exports.onNewMessage = functions.firestore.onDocumentCreated("matches/{matchId}/messages/{messageId}", async (event) => {
    var _a, _b, _c, _d, _e, _f;
    const msgData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!msgData)
        return;
    const senderId = (_b = msgData.senderId) !== null && _b !== void 0 ? _b : "";
    const text = (_c = msgData.text) !== null && _c !== void 0 ? _c : "";
    // Get match doc to find the recipient
    const matchDoc = await db
        .collection("matches")
        .doc(event.params.matchId)
        .get();
    const matchData = matchDoc.data();
    if (!matchData)
        return;
    const users = (_d = matchData.users) !== null && _d !== void 0 ? _d : [];
    const recipientUid = users.find((u) => u !== senderId);
    if (!recipientUid)
        return;
    const userNames = (_e = matchData.userNames) !== null && _e !== void 0 ? _e : {};
    const senderName = (_f = userNames[senderId]) !== null && _f !== void 0 ? _f : "Your match";
    const token = await getToken(recipientUid);
    if (!token)
        return;
    await sendTo(token, senderName, text.length > 80 ? text.substring(0, 80) + "…" : text, {
        type: "message",
        matchId: event.params.matchId,
        senderUid: senderId,
    });
});
// ─── 3. Announcement Broadcast ────────────────────────────────────────────────
// Fires when an admin writes to /announcements/{id}
// Sends the announcement to the "all_users" FCM topic.
// Users are subscribed to this topic when they open the app (see Flutter client).
exports.onAnnouncementCreated = functions.firestore.onDocumentCreated("announcements/{announcementId}", async (event) => {
    var _a, _b, _c;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data)
        return;
    const title = (_b = data.title) !== null && _b !== void 0 ? _b : "JuiceDates";
    const body = (_c = data.body) !== null && _c !== void 0 ? _c : "";
    if (!body)
        return;
    await messaging.send({
        topic: "all_users",
        notification: { title, body },
        android: { priority: "high" },
        apns: {
            payload: { aps: { sound: "default" } },
        },
    });
    functions.logger.info("Announcement broadcast sent", { title });
});
// ─── 4. User Banned — Cleanup ─────────────────────────────────────────────────
// Fires when a user document is updated.
// If isBanned flipped to true: deletes all their active matches and notifies admins.
exports.onUserBanned = functions.firestore.onDocumentUpdated("users/{uid}", async (event) => {
    var _a, _b, _c, _d, _e;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!before || !after)
        return;
    const wasBanned = (_c = before.isBanned) !== null && _c !== void 0 ? _c : false;
    const nowBanned = (_d = after.isBanned) !== null && _d !== void 0 ? _d : false;
    // Only act when isBanned flips from false → true
    if (wasBanned || !nowBanned)
        return;
    const uid = event.params.uid;
    const displayName = (_e = after.displayName) !== null && _e !== void 0 ? _e : uid;
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
    functions.logger.info(`Deleted ${matchesSnap.size} matches for banned user ${uid}`);
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
    }
    catch (_) {
        // No admins subscribed yet — safe to ignore
    }
});
//# sourceMappingURL=index.js.map