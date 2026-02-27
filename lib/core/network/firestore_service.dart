import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/user_models.dart';
import '../utils/juice_engine.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a photo to Firebase Storage and returns the download URL.
  Future<String> uploadPhoto(String uid, File file, int index) async {
    final ref = _storage.ref('users/$uid/photos/photo_$index.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
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

  /// Returns feed users, excluding:
  ///  - the current user themselves
  ///  - users already liked or passed
  ///  - banned users
  ///  - users who have blocked the current user
  Stream<List<JuiceUser>> getFeedUsers(String uid) {
    return _db
        .collection('users')
        .where('uid', isNotEqualTo: uid)
        .where('isBanned', isEqualTo: false)
        .snapshots()
        .asyncMap((snapshot) async {
      final currentUserDoc = await _db.collection('users').doc(uid).get();
      final currentUser = JuiceUser.fromFirestore(currentUserDoc);
      final excluded = <String>{
        ...currentUser.likedUids,
        ...currentUser.passedUids,
        ...currentUser.blockedUids,
        uid,
      };
      return snapshot.docs
          .map((doc) => JuiceUser.fromFirestore(doc))
          .where((u) {
            // Exclude if they blocked me
            if (u.blockedUids.contains(uid)) return false;
            return !excluded.contains(u.uid);
          })
          .toList();
    });
  }

  // ── Likes / Passes ────────────────────────────────────────────────────────

  /// Records a like atomically; creates a match if mutual (no duplicate matches).
  /// Returns the created [JuiceMatch] if mutual, or null.
  Future<JuiceMatch?> likeUser(JuiceUser fromUser, JuiceUser toUser) async {
    bool isMutual = false;

    // Atomically record the like and check mutuality
    await _db.runTransaction((txn) async {
      final toDoc =
          await txn.get(_db.collection('users').doc(toUser.uid));
      final theirLikes =
          List<String>.from(toDoc.data()?['likedUids'] ?? []);
      isMutual = theirLikes.contains(fromUser.uid);
      txn.update(_db.collection('users').doc(fromUser.uid), {
        'likedUids': FieldValue.arrayUnion([toUser.uid]),
      });
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
    return JuiceMatch.fromFirestore(doc);
  }

  Stream<List<JuiceMatch>> getMatches(String uid) {
    return _db
        .collection('matches')
        .where('users', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
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
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JuiceMessage.fromFirestore(doc.data()))
            .toList());
  }

  Future<void> sendMessage(String matchId, JuiceMessage message) async {
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
    final results = await Future.wait([
      _db.collection('users').count().get(),
      _db.collection('matches').count().get(),
      _db.collection('reports').where('resolved', isEqualTo: false).count().get(),
      _db.collection('events').count().get(),
    ]);
    return {
      'users': results[0].count ?? 0,
      'matches': results[1].count ?? 0,
      'reports': results[2].count ?? 0,
      'events': results[3].count ?? 0,
    };
  }

  Stream<List<JuiceUser>> getAllUsers() {
    return _db
        .collection('users')
        .orderBy('displayName')
        .snapshots()
        .map((s) => s.docs.map((d) => JuiceUser.fromFirestore(d)).toList());
  }

  Future<void> banUser(String uid) async {
    await _db.collection('users').doc(uid).update({'isBanned': true});
  }

  Future<void> unbanUser(String uid) async {
    await _db.collection('users').doc(uid).update({'isBanned': false});
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
  }
}
