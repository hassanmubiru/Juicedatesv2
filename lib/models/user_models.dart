import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/juice_engine.dart';

class JuiceUser {
  final String uid;
  final String displayName;
  final int age;
  final String? email;
  final String? photoUrl;
  final List<String> photos;
  final String? voiceUrl;
  final String city;
  final JuiceProfile juiceProfile;
  final String juiceSummary;
  final bool isPremium;
  final List<String> likedUids;
  final List<String> passedUids;
  final List<String> blockedUids;
  final String? bio;
  final List<String> interests;
  final String? fcmToken;
  final bool isAdmin;
  final bool isBanned;

  JuiceUser({
    required this.uid,
    required this.displayName,
    this.age = 25,
    this.email,
    this.photoUrl,
    required this.photos,
    this.voiceUrl,
    required this.city,
    required this.juiceProfile,
    required this.juiceSummary,
    this.isPremium = false,
    this.likedUids = const [],
    this.passedUids = const [],
    this.blockedUids = const [],
    this.bio,
    this.interests = const [],
    this.fcmToken,
    this.isAdmin = false,
    this.isBanned = false,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'age': age,
        'email': email,
        'photoUrl': photoUrl,
        'photos': photos,
        'voiceUrl': voiceUrl,
        'city': city,
        'juiceProfile': juiceProfile.toJson(),
        'juiceSummary': juiceSummary,
        'isPremium': isPremium,
        'likedUids': likedUids,
        'passedUids': passedUids,
        'blockedUids': blockedUids,
        'bio': bio,
        'interests': interests,
        'fcmToken': fcmToken,
        'isAdmin': isAdmin,
        'isBanned': isBanned,
      };

  factory JuiceUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JuiceUser(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      age: (data['age'] as num?)?.toInt() ?? 25,
      email: data['email'],
      photoUrl: data['photoUrl'],
      photos: List<String>.from(data['photos'] ?? []),
      voiceUrl: data['voiceUrl'],
      city: data['city'] ?? 'Unknown',
      juiceProfile: JuiceProfile.fromJson(data['juiceProfile'] ?? {}),
      juiceSummary: data['juiceSummary'] ?? '',
      isPremium: data['isPremium'] ?? false,
      likedUids: List<String>.from(data['likedUids'] ?? []),
      passedUids: List<String>.from(data['passedUids'] ?? []),
      blockedUids: List<String>.from(data['blockedUids'] ?? []),
      bio: data['bio'],
      interests: List<String>.from(data['interests'] ?? []),
      fcmToken: data['fcmToken'],
      isAdmin: data['isAdmin'] ?? false,
      isBanned: data['isBanned'] ?? false,
    );
  }
}

class JuiceMatch {
  final String matchId;
  final List<String> users;
  final Map<String, String> userNames;
  final Map<String, String?> userPhotos;
  final double sparksScore;
  final int tier;
  final int messageCount;
  final String lastMessage;
  final DateTime lastMessageTime;

  JuiceMatch({
    required this.matchId,
    required this.users,
    required this.userNames,
    required this.userPhotos,
    required this.sparksScore,
    required this.tier,
    this.messageCount = 0,
    this.lastMessage = '',
    required this.lastMessageTime,
  });

  String getPartnerUid(String myUid) =>
      users.firstWhere((u) => u != myUid, orElse: () => users.first);

  String getPartnerName(String myUid) =>
      userNames[getPartnerUid(myUid)] ?? 'Unknown';

  String? getPartnerPhoto(String myUid) => userPhotos[getPartnerUid(myUid)];

  factory JuiceMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawNames = Map<String, dynamic>.from(data['userNames'] ?? {});
    final rawPhotos = Map<String, dynamic>.from(data['userPhotos'] ?? {});
    return JuiceMatch(
      matchId: doc.id,
      users: List<String>.from(data['users'] ?? []),
      userNames: rawNames.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      userPhotos: rawPhotos.map((k, v) => MapEntry(k, v?.toString())),
      sparksScore: (data['sparksScore'] as num?)?.toDouble() ?? 0.0,
      tier: (data['tier'] as num?)?.toInt() ?? 1,
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 0,
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime:
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      tierUnlocked: (data['tierUnlocked'] as num?)?.toInt() ?? 1,
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class JuiceEvent {
  final String id;
  final String title;
  final String category;
  final String date;
  final int attendees;
  final List<String> attendeeUids;
  final String description;
  final String location;

  JuiceEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.attendees,
    this.attendeeUids = const [],
    this.description = '',
    this.location = 'Kampala, Uganda',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'category': category,
        'date': date,
        'attendees': attendees,
        'attendeeUids': attendeeUids,
        'description': description,
        'location': location,
      };

  factory JuiceEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JuiceEvent(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      date: data['date'] ?? '',
      attendees: (data['attendees'] as num?)?.toInt() ?? 0,
      attendeeUids: List<String>.from(data['attendeeUids'] ?? []),
      description: data['description'] ?? '',
      location: data['location'] ?? 'Kampala, Uganda',
    );
  }
}

class JuiceReport {
  final String id;
  final String reporterUid;
  final String reportedUid;
  final String reason;
  final DateTime timestamp;
  final bool resolved;

  JuiceReport({
    required this.id,
    required this.reporterUid,
    required this.reportedUid,
    required this.reason,
    required this.timestamp,
    this.resolved = false,
  });

  factory JuiceReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JuiceReport(
      id: doc.id,
      reporterUid: data['reporterUid'] ?? '',
      reportedUid: data['reportedUid'] ?? '',
      reason: data['reason'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolved: data['resolved'] ?? false,
    );
  }
}
