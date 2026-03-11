import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // ── Super Like ────────────────────────────────────────────────────────────

  static const int _freeDailySuperLikeLimit = 3;

  /// Returns super likes left today, or null for premium (unlimited).
  Future<int?> getSuperLikesLeft(String uid, bool isPremium) async {
    if (isPremium) return null;
    final doc = await _db.collection('users').doc(uid).get();
    final todayStr = _todayString();
    final storedDate = doc.data()?['dailySuperLikeDate'] as String? ?? '';
    final storedCount =
        (doc.data()?['dailySuperLikeCount'] as num?)?.toInt() ?? 0;
    final count = storedDate == todayStr ? storedCount : 0;
    return (_freeDailySuperLikeLimit - count)
        .clamp(0, _freeDailySuperLikeLimit);
  }

  /// Records a super like. Counts as a regular like too.
  /// Creates a match if the target already liked/superliked back.
  /// Throws [DailyLimitException] when free user exhausts 3/day quota.
  Future<JuiceMatch?> superLikeUser(
      JuiceUser fromUser, JuiceUser toUser) async {
    bool isMutual = false;
    final todayStr = _todayString();

    await _db.runTransaction((txn) async {
      final fromDoc =
          await txn.get(_db.collection('users').doc(fromUser.uid));
      final toDoc =
          await txn.get(_db.collection('users').doc(toUser.uid));

      if (!fromUser.isPremium) {
        final storedDate =
            fromDoc.data()?['dailySuperLikeDate'] as String? ?? '';
        final storedCount =
            (fromDoc.data()?['dailySuperLikeCount'] as num?)?.toInt() ?? 0;
        final todayCount = storedDate == todayStr ? storedCount : 0;
        if (todayCount >= _freeDailySuperLikeLimit) {
          throw DailyLimitException();
        }
        txn.update(_db.collection('users').doc(fromUser.uid), {
          'superLikedUids': FieldValue.arrayUnion([toUser.uid]),
          'likedUids': FieldValue.arrayUnion([toUser.uid]),
          'dailySuperLikeDate': todayStr,
          'dailySuperLikeCount':
              storedDate == todayStr ? FieldValue.increment(1) : 1,
        });
      } else {
        txn.update(_db.collection('users').doc(fromUser.uid), {
          'superLikedUids': FieldValue.arrayUnion([toUser.uid]),
          'likedUids': FieldValue.arrayUnion([toUser.uid]),
        });
      }

      final theirLikes =
          List<String>.from(toDoc.data()?['likedUids'] ?? []);
      final theirSuperLikes =
          List<String>.from(toDoc.data()?['superLikedUids'] ?? []);
      isMutual = theirLikes.contains(fromUser.uid) ||
          theirSuperLikes.contains(fromUser.uid);
    });

    if (!isMutual) return null;

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

  // ── Who Liked Me ──────────────────────────────────────────────────────────

  /// Returns a stream of users who liked the current user and aren't yet matched.
  Stream<List<JuiceUser>> getUsersWhoLikedMe(String uid) {
    return _db
        .collection('users')
        .where('likedUids', arrayContains: uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final matchSnap = await _db
          .collection('matches')
          .where('users', arrayContains: uid)
          .get();
      final matchedUids = <String>{};
      for (final doc in matchSnap.docs) {
        final users = List<String>.from(doc.data()['users'] ?? []);
        matchedUids.addAll(users.where((u) => u != uid));
      }
      final myDoc = await _db.collection('users').doc(uid).get();
      final blockedUids = Set<String>.from(
          List<String>.from(myDoc.data()?['blockedUids'] ?? []));
      return snapshot.docs
          .map((doc) => JuiceUser.fromFirestore(doc))
          .where((u) =>
              !matchedUids.contains(u.uid) &&
              !blockedUids.contains(u.uid) &&
              u.uid != uid &&
              !u.isBanned)
          .toList();
    });
  }

  // ── Profile Views ─────────────────────────────────────────────────────────

  /// Records that [viewerUid] viewed [profileUid]'s profile.
  Future<void> recordProfileView(String viewerUid, String profileUid) async {
    if (viewerUid == profileUid) return;
    await _db
        .collection('users')
        .doc(profileUid)
        .collection('profileViews')
        .doc(viewerUid)
        .set({'viewedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
  }

  /// Returns how many distinct people viewed [uid]'s profile in the last 7 days.
  Future<int> getProfileViewCount(String uid) async {
    try {
      final cutoff = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 7)));
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('profileViews')
          .where('viewedAt', isGreaterThan: cutoff)
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  /// For premium users: returns the profiles of recent viewers (last 7 days, max 20).
  Future<List<JuiceUser>> getProfileViewers(String uid) async {
    try {
      final cutoff = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 7)));
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('profileViews')
          .where('viewedAt', isGreaterThan: cutoff)
          .orderBy('viewedAt', descending: true)
          .limit(20)
          .get();
      if (snap.docs.isEmpty) return [];
      final userDocs = await Future.wait(
          snap.docs.map((d) => _db.collection('users').doc(d.id).get()));
      return userDocs
          .where((d) => d.exists)
          .map((d) => JuiceUser.fromFirestore(d))
          .toList();
    } catch (_) {
      return [];
    }
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
      'createdAt': FieldValue.serverTimestamp(),
      'readByUids': [],
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

  /// Marks a match as read by [uid].
  Future<void> markMatchRead(String matchId, String uid) async {
    await _db.collection('matches').doc(matchId).update({
      'readByUids': FieldValue.arrayUnion([uid]),
    });
  }

  /// Stream of how many NEW (unread) matches the user has.
  Stream<int> getUnreadMatchCount(String uid) {
    return _db
        .collection('matches')
        .where('users', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs
            .where((d) =>
                !List<String>.from(d.data()['readByUids'] ?? []).contains(uid))
            .length);
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
      'type': message.type,
      if (message.giftEmoji != null) 'giftEmoji': message.giftEmoji,
      // Sender has already "read" the message they just sent
      'readBy': [message.senderId],
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

  Future<void> createEvent(JuiceEvent event) async {
    final data = event.toJson();
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('events').add(data);
  }

  Future<void> replyToMoment({
    required String momentId,
    required String replierUid,
    required String replierName,
    required String text,
  }) async {
    await _db
        .collection('moments')
        .doc(momentId)
        .collection('replies')
        .add({
      'uid': replierUid,
      'name': replierName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Moments (24-hour stories) ────────────────────────────────────────────

  Future<void> requestPremium(String uid) async {
    await _db
        .collection('users')
        .doc(uid)
        .update({'premiumRequested': true});
  }

  Future<void> postMoment(
    String uid,
    String displayName,
    String? photoUrl,
    String text, {
    String? imageUrl,
  }) async {
    final now = DateTime.now();
    await _db.collection('moments').add({
      'uid': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'text': text,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt':
          Timestamp.fromDate(now.add(const Duration(hours: 24))),
    });
  }

  /// Stream of active (non-expired) moments, excluding blocked users.
  Stream<List<JuiceMoment>> getActiveMoments(String currentUid) {
    return _db
        .collection('moments')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: false)
        .limit(50)
        .snapshots()
        .asyncMap((snap) async {
      try {
        final currentDoc =
            await _db.collection('users').doc(currentUid).get();
        final blocked = List<String>.from(
            currentDoc.data()?['blockedUids'] ?? []);
        return snap.docs
            .where((d) => !blocked.contains((d.data())['uid']))
            .map((d) => JuiceMoment.fromFirestore(d))
            .toList();
      } catch (_) {
        return snap.docs
            .map((d) => JuiceMoment.fromFirestore(d))
            .toList();
      }
    });
  }

  Future<void> deleteMoment(String momentId) async {
    await _db.collection('moments').doc(momentId).delete();
  }

  // ── Winks ─────────────────────────────────────────────────────────

  /// Sends a wink. Deduped per sender/receiver per day.
  Future<void> winkUser(
      String fromUid, String fromName, String? fromPhoto, String toUid) async {
    if (fromUid == toUid) return;
    final today = _todayString();
    final existing = await _db
        .collection('winks')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('date', isEqualTo: today)
        .get();
    if (existing.docs.isNotEmpty) return; // already winked today
    await _db.collection('winks').add({
      'fromUid': fromUid,
      'toUid': toUid,
      'fromName': fromName,
      'fromPhoto': fromPhoto,
      'date': today,
      'createdAt': FieldValue.serverTimestamp(),
      'seen': false,
    });
  }

  Stream<List<JuiceWink>> getWinksReceived(String uid) {
    return _db
        .collection('winks')
        .where('toUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => JuiceWink.fromFirestore(d)).toList());
  }

  Future<void> markWinkSeen(String winkId) async {
    await _db.collection('winks').doc(winkId).update({'seen': true});
  }

  // ── Boost (Tinder-style – 30-min visibility bump) ─────────────────────────

  /// Sets [boostExpiresAt] for the given user to 30 minutes from now.
  Future<void> boostUser(String uid) async {
    final expiresAt = DateTime.now().add(const Duration(minutes: 30));
    await _db.collection('users').doc(uid).update({
      'boostExpiresAt': Timestamp.fromDate(expiresAt),
    });
  }

  /// Returns true when the user currently has an active boost.
  Future<bool> isBoostActive(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final raw = doc.data()?['boostExpiresAt'];
    if (raw == null) return false;
    return (raw as Timestamp).toDate().isAfter(DateTime.now());
  }

  // ── Top Picks (daily curated – premium) ──────────────────────────────────

  /// Returns up to 10 high-compatibility users the current user has NOT yet
  /// liked/passed/blocked.  Premium gate enforced by the call site.
  Future<List<JuiceUser>> getTopPicks(String uid) async {
    final currentDoc = await _db.collection('users').doc(uid).get();
    final current = JuiceUser.fromFirestore(currentDoc);
    final excluded = <String>{
      ...current.likedUids,
      ...current.passedUids,
      ...current.blockedUids,
      uid,
    };
    final snap = await _db.collection('users').limit(200).get();
    final candidates = snap.docs
        .map((d) => JuiceUser.fromFirestore(d))
        .where((u) => !excluded.contains(u.uid) && !u.isAdmin && !u.isBanned)
        .toList();
    candidates.sort((a, b) {
      final sA = JuiceEngine.computeSparks(current.juiceProfile, a.juiceProfile);
      final sB = JuiceEngine.computeSparks(current.juiceProfile, b.juiceProfile);
      return sB.compareTo(sA);
    });
    return candidates.take(10).toList();
  }

  // ── Read Receipts (per-message) ───────────────────────────────────────────

  /// Marks all messages in [matchId] as read by [uid] (sets readBy on each).
  Future<void> markMessagesRead(String matchId, String uid) async {
    try {
      final snap = await _db
          .collection('matches')
          .doc(matchId)
          .collection('messages')
          .where('senderId', isNotEqualTo: uid)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(uid)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([uid]),
          });
        }
      }
      await batch.commit();
    } catch (_) {
      // Non-critical; ignore errors silently
    }
  }

  // ── Delete Account ────────────────────────────────────────────────────────

  /// Hard-deletes the user's Firestore document and signs them out.
  /// Does NOT delete Firebase Auth account (requires re-auth on client for that).
  Future<void> deleteAccount(String uid) async {
    // Delete profile views subcollection (best effort)
    try {
      final views = await _db
          .collection('users')
          .doc(uid)
          .collection('profileViews')
          .get();
      final batch = _db.batch();
      for (final d in views.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (_) {}

    // Remove from liked/passed lists of others would require a cloud function;
    // here we just delete the user document itself.
    await _db.collection('users').doc(uid).delete();
  }

  Future<void> submitVerificationRequest({
    required String uid,
    required String displayName,
    required String selfieUrl,
  }) async {
    await _db.collection('verificationRequests').add({
      'uid': uid,
      'displayName': displayName,
      'selfieUrl': selfieUrl,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    });
    // Mark user as verification-pending so the badge can show as pending
    await _db.collection('users').doc(uid).update({'verificationStatus': 'pending'});
  }
}

/// Thrown when a free user has exhausted their daily like quota.
class DailyLimitException implements Exception {
  const DailyLimitException();
  @override
  String toString() => 'Daily like limit reached. Upgrade to Juice Plus+ for unlimited likes.';
}