import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_models.dart';
import '../utils/juice_engine.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  /// Returns all users except the current user, filtering out already-liked
  /// and already-passed UIDs client-side.
  Stream<List<JuiceUser>> getFeedUsers(String uid) {
    return _db
        .collection('users')
        .where('uid', isNotEqualTo: uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final currentUserDoc = await _db.collection('users').doc(uid).get();
      final currentUser = JuiceUser.fromFirestore(currentUserDoc);
      final excluded = <String>{
        ...currentUser.likedUids,
        ...currentUser.passedUids,
        uid,
      };
      return snapshot.docs
          .map((doc) => JuiceUser.fromFirestore(doc))
          .where((u) => !excluded.contains(u.uid))
          .toList();
    });
  }

  // ── Likes / Passes ────────────────────────────────────────────────────────

  /// Records a like, then checks for a mutual match.
  /// Returns the created [JuiceMatch] if mutual, or null.
  Future<JuiceMatch?> likeUser(JuiceUser fromUser, JuiceUser toUser) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(fromUser.uid), {
      'likedUids': FieldValue.arrayUnion([toUser.uid]),
    });
    await batch.commit();

    final toUserDoc = await _db.collection('users').doc(toUser.uid).get();
    final toUserFresh = JuiceUser.fromFirestore(toUserDoc);
    if (toUserFresh.likedUids.contains(fromUser.uid)) {
      final sparks = JuiceEngine.computeSparks(
        fromUser.juiceProfile,
        toUser.juiceProfile,
      );
      return await _createMatch(fromUser, toUser, sparks);
    }
    return null;
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

  Future<void> updateMatchTier(String matchId, int tier) async {
    await _db.collection('matches').doc(matchId).update({'tier': tier});
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
    batch.update(_db.collection('matches').doc(matchId), {
      'lastMessage': message.text,
      'lastMessageTime': FieldValue.serverTimestamp(),
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
}
