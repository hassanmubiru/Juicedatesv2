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
  final bool premiumRequested;
  final List<String> likedUids;
  final List<String> passedUids;
  final List<String> blockedUids;
  final List<String> superLikedUids;
  final String? bio;
  final List<String> interests;
  final String? fcmToken;
  final bool isAdmin;
  final bool isBanned;
  final String? sexualOrientation;
  final String? university;
  final bool showAge;
  final String? jobTitle;
  final String? company;
  // Discovery settings
  final double maxDistance;
  final int ageRangeMin;
  final int ageRangeMax;
  final String showGender; // 'everyone' | 'men' | 'women'
  final String? passportCity;
  // Boost (Tinder-style)
  final DateTime? boostExpiresAt;
  final String? verificationStatus; // null | 'pending' | 'verified' | 'rejected'

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
    this.premiumRequested = false,
    this.likedUids = const [],
    this.passedUids = const [],
    this.blockedUids = const [],
    this.superLikedUids = const [],
    this.bio,
    this.interests = const [],
    this.fcmToken,
    this.isAdmin = false,
    this.isBanned = false,
    this.sexualOrientation,
    this.university,
    this.showAge = true,
    this.jobTitle,
    this.company,
    this.maxDistance = 100,
    this.ageRangeMin = 18,
    this.ageRangeMax = 50,
    this.showGender = 'everyone',
    this.passportCity,
    this.boostExpiresAt,
    this.verificationStatus,
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
        'premiumRequested': premiumRequested,
        'likedUids': likedUids,
        'passedUids': passedUids,
        'blockedUids': blockedUids,
        'superLikedUids': superLikedUids,
        'bio': bio,
        'interests': interests,
        'fcmToken': fcmToken,
        'isAdmin': isAdmin,
        'isBanned': isBanned,
        'sexualOrientation': sexualOrientation,
        'university': university,
        'showAge': showAge,
        'jobTitle': jobTitle,
        'company': company,
        'maxDistance': maxDistance,
        'ageRangeMin': ageRangeMin,
        'ageRangeMax': ageRangeMax,
        'showGender': showGender,
        'passportCity': passportCity,
        'boostExpiresAt': boostExpiresAt != null
            ? Timestamp.fromDate(boostExpiresAt!)
            : null,
        if (verificationStatus != null) 'verificationStatus': verificationStatus,
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
      premiumRequested: data['premiumRequested'] ?? false,
      likedUids: List<String>.from(data['likedUids'] ?? []),
      passedUids: List<String>.from(data['passedUids'] ?? []),
      blockedUids: List<String>.from(data['blockedUids'] ?? []),
      superLikedUids: List<String>.from(data['superLikedUids'] ?? []),
      bio: data['bio'],
      interests: List<String>.from(data['interests'] ?? []),
      fcmToken: data['fcmToken'],
      isAdmin: data['isAdmin'] ?? false,
      isBanned: data['isBanned'] ?? false,
      sexualOrientation: data['sexualOrientation'],
      university: data['university'],
      showAge: data['showAge'] ?? true,
      jobTitle: data['jobTitle'],
      company: data['company'],
      maxDistance: (data['maxDistance'] as num?)?.toDouble() ?? 100,
      ageRangeMin: (data['ageRangeMin'] as num?)?.toInt() ?? 18,
      ageRangeMax: (data['ageRangeMax'] as num?)?.toInt() ?? 50,
      showGender: data['showGender'] ?? 'everyone',
      passportCity: data['passportCity'],
      boostExpiresAt: (data['boostExpiresAt'] as Timestamp?)?.toDate(),
      verificationStatus: data['verificationStatus'],
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
  final DateTime? createdAt;
  final List<String> readByUids;

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
    this.createdAt,
    this.readByUids = const [],
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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      readByUids: List<String>.from(data['readByUids'] ?? []),
    );
  }
}

class JuiceMessage {
  final String senderId;
  final String text;
  final String? voiceUrl;
  final int tierUnlocked;
  final DateTime timestamp;
  /// 'text' | 'gift'
  final String type;
  /// only set when type == 'gift'
  final String? giftEmoji;
  /// UIDs that have read (seen) this message
  final List<String> readBy;

  JuiceMessage({
    required this.senderId,
    required this.text,
    this.voiceUrl,
    required this.tierUnlocked,
    required this.timestamp,
    this.type = 'text',
    this.giftEmoji,
    this.readBy = const [],
  });

  factory JuiceMessage.fromFirestore(Map<String, dynamic> data) {
    return JuiceMessage(
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      voiceUrl: data['voiceUrl'],
      tierUnlocked: (data['tierUnlocked'] as num?)?.toInt() ?? 1,
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'text',
      giftEmoji: data['giftEmoji'],
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }
}

// ── Moments (24-hour stories) ─────────────────────────────────────────────

class JuiceMoment {
  final String id;
  final String uid;
  final String displayName;
  final String? authorPhotoUrl;
  final String text;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime expiresAt;

  JuiceMoment({
    required this.id,
    required this.uid,
    required this.displayName,
    this.authorPhotoUrl,
    required this.text,
    this.imageUrl,
    required this.createdAt,
    required this.expiresAt,
  });

  factory JuiceMoment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JuiceMoment(
      id: doc.id,
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? '',
      authorPhotoUrl: data['photoUrl'],
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 24)),
    );
  }
}

// ── Winks ─────────────────────────────────────────────────────────────────

class JuiceWink {
  final String id;
  final String fromUid;
  final String fromName;
  final String? fromPhoto;
  final DateTime createdAt;
  final bool seen;

  JuiceWink({
    required this.id,
    required this.fromUid,
    required this.fromName,
    this.fromPhoto,
    required this.createdAt,
    required this.seen,
  });

  factory JuiceWink.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JuiceWink(
      id: doc.id,
      fromUid: data['fromUid'] ?? '',
      fromName: data['fromName'] ?? '',
      fromPhoto: data['fromPhoto'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seen: data['seen'] ?? false,
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
