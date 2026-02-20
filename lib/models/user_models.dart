import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/juice_engine.dart';

class JuiceUser {
  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final List<String> photos;
  final String? voiceUrl;
  final String city;
  final JuiceProfile juiceProfile;
  final String juiceSummary;
  final bool isPremium;

  JuiceUser({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    required this.photos,
    this.voiceUrl,
    required this.city,
    required this.juiceProfile,
    required this.juiceSummary,
    this.isPremium = false,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'photos': photos,
        'voiceUrl': voiceUrl,
        'city': city,
        'juiceProfile': juiceProfile.toJson(),
        'juiceSummary': juiceSummary,
        'isPremium': isPremium,
      };

  factory JuiceUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JuiceUser(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'],
      photoUrl: data['photoUrl'],
      photos: List<String>.from(data['photos'] ?? []),
      voiceUrl: data['voiceUrl'],
      city: data['city'] ?? 'Unknown',
      juiceProfile: JuiceProfile.fromJson(data['juiceProfile'] ?? {}),
      juiceSummary: data['juiceSummary'] ?? '',
      isPremium: data['isPremium'] ?? false,
    );
  }
}

class JuiceMatch {
  final String matchId;
  final List<String> users;
  final double sparksScore;
  final int tier;
  final DateTime lastMessageTime;

  JuiceMatch({
    required this.matchId,
    required this.users,
    required this.sparksScore,
    required this.tier,
    required this.lastMessageTime,
  });

  factory JuiceMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JuiceMatch(
      matchId: doc.id,
      users: List<String>.from(data['users'] ?? []),
      sparksScore: (data['sparksScore'] as num?)?.toDouble() ?? 0.0,
      tier: data['tier'] ?? 1,
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class JuiceMessage {
  final String senderId;
  final String text;
  final String? voiceUrl;
  final int tierUnlocked;
  final DateTime timestamp;

  JuiceMessage({
    required this.senderId,
    required this.text,
    this.voiceUrl,
    required this.tierUnlocked,
    required this.timestamp,
  });

  factory JuiceMessage.fromFirestore(Map<String, dynamic> data) {
    return JuiceMessage(
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      voiceUrl: data['voiceUrl'],
      tierUnlocked: data['tierUnlocked'] ?? 1,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
