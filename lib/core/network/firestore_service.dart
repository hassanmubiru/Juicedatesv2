import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_models.dart';
import '../utils/juice_engine.dart';
import 'cloudinary_service.dart';
import 'notify_service.dart';

final _notify = NotifyService.instance;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _cloudinary = CloudinaryService();

  /// Uploads a photo to Cloudinary and returns the CDN URL.
  /// Cloudinary free tier: 25 GB storage + bandwidth, zero egress fees.
  Future<String> uploadPhoto(String uid, File file, int index) async {
    return _cloudinary.uploadPhoto(
      file: file,
      publicId: 'juicedates/users/$uid/photo_$index',
    );
  }

  Future<void> blockUser(String myUid, String blockedUid) async {
    await _db.collection('users').doc(myUid).update({
      'blockedUids': FieldValue.arrayUnion([blockedUid]),
    });
  }

  Future<void> reportUser(String reporterUid, String reportedUid, String reason) async {
    await _db.collection('reports').add({
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'reason': reason,
      'resolved': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<void> createUser(JuiceUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toJson());
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Stream<JuiceUser> getUser(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => JuiceUser.fromFirestore(doc));
  }

  Future<JuiceUser?> getUserOnce(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return JuiceUser.fromFirestore(doc);
  }

  /// Returns feed candidates sorted by Sparks compatibility (best match first).
  /// Premium users: passed users are shown again + larger pool so they never run out.
  Stream<List<JuiceUser>> getFeedUsers(String uid,
      {int limit = 60, bool isPremium = false}) {
    return _db
        .collection('users')
        .limit(isPremium ? 200 : limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final currentUserDoc = await _db.collection('users').doc(uid).get();
      final currentUser = JuiceUser.fromFirestore(currentUserDoc);
      final excluded = <String>{
        ...currentUser.likedUids,
        // Premium users can re-see passed profiles — they never run out
        if (!isPremium) ...currentUser.passedUids,
        ...currentUser.blockedUids,
        uid,
      };
      final users = snapshot.docs
          .map((doc) => JuiceUser.fromFirestore(doc))
          .where((u) =>
              !excluded.contains(u.uid) &&
              !u.blockedUids.contains(uid) &&
              u.isBanned != true &&
              !u.isAdmin)
          .toList();
      // Sort best matches first using the Sparks algorithm
      users.sort((a, b) {
        final sA = JuiceEngine.computeSparks(
            currentUser.juiceProfile, a.juiceProfile);
        final sB = JuiceEngine.computeSparks(
            currentUser.juiceProfile, b.juiceProfile);
        return sB.compareTo(sA);
      });
      return users;
    });
  }

  // ── Likes / Passes ────────────────────────────────────────────────────────

  static const int _freeDailyLikeLimit = 50;

  /// Returns how many likes the user has left today, or null for premium (unlimited).
  Future<int?> getDailyLikesLeft(String uid, bool isPremium) async {
    if (isPremium) return null;
    final doc = await _db.collection('users').doc(uid).get();
    final todayStr = _todayString();
    final storedDate = doc.data()?['dailyLikeDate'] as String? ?? '';
    final storedCount =
        (doc.data()?['dailyLikeCount'] as num?)?.toInt() ?? 0;
    final count = storedDate == todayStr ? storedCount : 0;
    return (_freeDailyLikeLimit - count).clamp(0, _freeDailyLikeLimit);
  }

  String _todayString() {
    final t = DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2,'0')}-${t.day.toString().padLeft(2,'0')}';
  }

  /// Records a like atomically; creates a match if mutual (no duplicate matches).
  /// Throws a [DailyLimitException] when a free user exhausts their daily quota.
  /// Returns the created [JuiceMatch] if mutual, or null.
  Future<JuiceMatch?> likeUser(JuiceUser fromUser, JuiceUser toUser) async {
    bool isMutual = false;
    final todayStr = _todayString();

    // Atomically record the like, enforce daily limit, and check mutuality
    await _db.runTransaction((txn) async {
      final fromDoc =
          await txn.get(_db.collection('users').doc(fromUser.uid));
      final toDoc =
          await txn.get(_db.collection('users').doc(toUser.uid));

      // ── Daily like limit (free users only) ──────────────────────────────
      if (!fromUser.isPremium) {
        final storedDate =
            fromDoc.data()?['dailyLikeDate'] as String? ?? '';
        final storedCount =
            (fromDoc.data()?['dailyLikeCount'] as num?)?.toInt() ?? 0;
        final todayCount = storedDate == todayStr ? storedCount : 0;
        if (todayCount >= _freeDailyLikeLimit) {
          throw DailyLimitException();
        }
        txn.update(_db.collection('users').doc(fromUser.uid), {
          'likedUids': FieldValue.arrayUnion([toUser.uid]),
          'dailyLikeDate': todayStr,
          'dailyLikeCount':
              storedDate == todayStr ? FieldValue.increment(1) : 1,
        });
      } else {
        txn.update(_db.collection('users').doc(fromUser.uid), {
          'likedUids': FieldValue.arrayUnion([toUser.uid]),
        });
      }

      final theirLikes =
          List<String>.from(toDoc.data()?['likedUids'] ?? []);
      isMutual = theirLikes.contains(fromUser.uid);
    });

    if (!isMutual) return null;

    // Guard: check whether a match between these two already exists
    final existing = await _db
        .collection('matches')
        .where('users', arrayContains: fromUser.uid)
        .get();
    final alreadyMatched = existing.docs.any((d) {
      final users = List<String>.from(d.data()['users'] ?? []);
      return users.contains(toUser.uid);
    });
    if (alreadyMatched) return null;

    final sparks =
        JuiceEngine.computeSparks(fromUser.juiceProfile, toUser.juiceProfile);
    return await _createMatch(fromUser, toUser, sparks);
  }

  Future<void> passUser(String fromUid, String toUid) async {
    await _db.collection('users').doc(fromUid).update({
      'passedUids': FieldValue.arrayUnion([toUid]),
    });
  }

  // ── Matches ───────────────────────────────────────────────────────────────

  Future<JuiceMatch> _createMatch(
      JuiceUser user1, JuiceUser user2, double sparksScore) async {
    final ref = _db.collection('matches').doc();
    await ref.set({
      'users': [user1.uid, user2.uid],
      'userNames': {user1.uid: user1.displayName, user2.uid: user2.displayName},
      'userPhotos': {user1.uid: user1.photoUrl, user2.uid: user2.photoUrl},
      'sparksScore': sparksScore,
      'tier': 1,
      'messageCount': 0,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
    final doc = await ref.get();
    final match = JuiceMatch.fromFirestore(doc);
    // Push notifications (fire-and-forget)
    _notify.notifyMatch(
      uid1: user1.uid, uid2: user2.uid,
      name1: user1.displayName, name2: user2.displayName,
      matchId: match.matchId, sparksScore: sparksScore,
    );
    return match;
  }

  Stream<List<JuiceMatch>> getMatches(String uid) {
    return _db
        .collection('matches')
        .where('users', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .limit(50) // cap at 50 — nobody has more active convos
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => JuiceMatch.fromFirestore(doc)).toList());
  }

  Future<JuiceMatch?> getMatchOnce(String matchId) async {
    final doc = await _db.collection('matches').doc(matchId).get();
    if (!doc.exists) return null;
    return JuiceMatch.fromFirestore(doc);
  }

  Future<void> updateMatchTier(String matchId, int tier, int messageCount) async {
    await _db.collection('matches').doc(matchId).update({
      'tier': tier,
      'messageCount': messageCount,
    });
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Stream<List<JuiceMessage>> getMessages(String matchId) {
    return _db
        .collection('matches')
        .doc(matchId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(100) // only stream the last 100 messages
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JuiceMessage.fromFirestore(doc.data()))
            .toList());
  }

  Future<void> sendMessage(
    String matchId,
    JuiceMessage message, {
    String? recipientUid,
    String? senderName,
  }) async {
    final batch = _db.batch();
    final msgRef = _db
        .collection('matches')
        .doc(matchId)
        .collection('messages')
        .doc();
    batch.set(msgRef, {
      'senderId': message.senderId,
      'text': message.text,
      'voiceUrl': message.voiceUrl,
      'tierUnlocked': message.tierUnlocked,
      'timestamp': FieldValue.serverTimestamp(),
    });
    // Atomically bump messageCount and lastMessage in the same write
    batch.update(_db.collection('matches').doc(matchId), {
      'lastMessage': message.text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'messageCount': FieldValue.increment(1),
    });
    await batch.commit();
    // Push notification to recipient (fire-and-forget)
    if (recipientUid != null && message.text.isNotEmpty) {
      _notify.notifyMessage(
        senderUid: message.senderId,
        senderName: senderName ?? 'Your match',
        recipientUid: recipientUid,
        matchId: matchId,
        text: message.text,
      );
    }
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Stream<List<JuiceEvent>> getEvents() {
    return _db
        .collection('events')
        .orderBy('date')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => JuiceEvent.fromFirestore(doc)).toList());
  }

  Future<void> rsvpEvent(String eventId, String uid) async {
    await _db.collection('events').doc(eventId).update({
      'attendeeUids': FieldValue.arrayUnion([uid]),
      'attendees': FieldValue.increment(1),
    });
  }

  Future<void> cancelRsvp(String eventId, String uid) async {
    await _db.collection('events').doc(eventId).update({
      'attendeeUids': FieldValue.arrayRemove([uid]),
      'attendees': FieldValue.increment(-1),
    });
  }

  // ── Admin ─────────────────────────────────────────────────────────────────

  Future<Map<String, int>> getAdminStats() async {
    Future<int> safeCount(Future<QuerySnapshot> query) async {
      try {
        final snap = await query;
        return snap.docs.length;
      } catch (_) {
        return 0;
      }
    }

    final results = await Future.wait([
      safeCount(_db.collection('users').get()),
      safeCount(_db.collection('matches').get()),
      safeCount(
          _db.collection('reports').where('resolved', isEqualTo: false).get()),
      safeCount(_db.collection('events').get()),
      safeCount(_db
          .collection('users')
          .where('premiumRequested', isEqualTo: true)
          .get()),
    ]);
    return {
      'users': results[0],
      'matches': results[1],
      'reports': results[2],
      'events': results[3],
      'plusRequests': results[4],
    };
  }

  Stream<List<JuiceUser>> getAllUsers() {
    return _db
        .collection('users')
        .orderBy('displayName')
        .snapshots()
        .map((s) => s.docs.map((d) => JuiceUser.fromFirestore(d)).toList());
  }

  Future<void> banUser(String uid, String displayName) async {
    await _db.collection('users').doc(uid).update({'isBanned': true});
    // Delete matches + notify admins via server (fire-and-forget)
    _notify.notifyBan(uid: uid, displayName: displayName);
  }

  Future<void> unbanUser(String uid) async {
    await _db.collection('users').doc(uid).update({'isBanned': false});
  }

  Future<void> toggleAdmin(String uid, bool makeAdmin) async {
    await _db.collection('users').doc(uid).update({'isAdmin': makeAdmin});
  }

  Future<void> togglePremium(String uid, bool makePremium) async {
    await _db.collection('users').doc(uid).update({'isPremium': makePremium});
  }

  Future<void> requestPremium(String uid) async {
    await _db
        .collection('users')
        .doc(uid)
        .update({'premiumRequested': true});
  }

  Future<void> deleteUserAccount(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  Stream<List<JuiceReport>> getAllReports() {
    return _db
        .collection('reports')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => JuiceReport.fromFirestore(d)).toList());
  }

  Future<void> resolveReport(String reportId) async {
    await _db.collection('reports').doc(reportId).update({'resolved': true});
  }

  Future<void> createEvent(JuiceEvent event) async {
    await _db.collection('events').add(event.toJson());
  }

  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    await _db.collection('events').doc(id).update(data);
  }

  Future<void> deleteEvent(String id) async {
    await _db.collection('events').doc(id).delete();
  }

  Future<void> sendAnnouncement(String title, String body) async {
    await _db.collection('announcements').add({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'sentBy': FirebaseAuth.instance.currentUser?.uid,
    });
    // Broadcast FCM to all users via server (fire-and-forget)
    _notify.notifyAnnouncement(title: title, body: body);
  }
}

/// Thrown when a free user has exhausted their daily like quota.
class DailyLimitException implements Exception {
  const DailyLimitException();
  @override
  String toString() => 'Daily like limit reached. Upgrade to Juice Plus+ for unlimited likes.';
}
