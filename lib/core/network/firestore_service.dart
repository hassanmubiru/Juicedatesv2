import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_models.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser(JuiceUser user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toJson());
  }

  Stream<JuiceUser> getUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
      (doc) => JuiceUser.fromFirestore(doc),
    );
  }

  Stream<List<JuiceMatch>> getMatches(String uid) {
    return _firestore
        .collection('matches')
        .where('users', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JuiceMatch.fromFirestore(doc))
            .toList());
  }

  Stream<List<JuiceMessage>> getMessages(String matchId) {
    return _firestore
        .collection('matches')
        .doc(matchId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JuiceMessage.fromFirestore(doc.data()))
            .toList());
  }

  Future<void> sendMessage(String matchId, JuiceMessage message) async {
    await _firestore
        .collection('matches')
        .doc(matchId)
        .collection('messages')
        .add({
      'senderId': message.senderId,
      'text': message.text,
      'voiceUrl': message.voiceUrl,
      'tierUnlocked': message.tierUnlocked,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
