# JuiceDates Backend Wiring Plan

## Overview
Wire all screens to real Firebase/Firestore backend — replace all mock/hardcoded data.

---

## Step 1 — `pubspec.yaml`

Add `google_sign_in: ^6.2.1` after `permission_handler`:

```yaml
  permission_handler: ^11.3.1
  google_sign_in: ^6.2.1
  intl: ^0.19.0
```

Then run: `flutter pub get`

---

## Step 2 — `lib/models/user_models.dart`

Add `age`, `likedUids`, `passedUids` to `JuiceUser`; enrich `JuiceMatch` with `userNames`, `userPhotos`, `lastMessage`; add new `JuiceEvent` model.

```dart
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
  final String lastMessage;
  final DateTime lastMessageTime;

  JuiceMatch({
    required this.matchId,
    required this.users,
    required this.userNames,
    required this.userPhotos,
    required this.sparksScore,
    required this.tier,
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
```

---

## Step 3 — `lib/core/network/firestore_service.dart`

Full replacement with all missing methods: `getFeedUsers`, `likeUser`, `passUser`, `_createMatch`, `updateMatchTier`, `getEvents`, `rsvpEvent`, `cancelRsvp`, `getUserOnce`, `updateUserProfile`.

```dart
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

    // Add toUser to fromUser's likedUids
    batch.update(_db.collection('users').doc(fromUser.uid), {
      'likedUids': FieldValue.arrayUnion([toUser.uid]),
    });
    await batch.commit();

    // Check for mutual like
    final toUserDoc = await _db.collection('users').doc(toUser.uid).get();
    final toUserFresh = JuiceUser.fromFirestore(toUserDoc);
    if (toUserFresh.likedUids.contains(fromUser.uid)) {
      // Mutual match — compute Sparks and create match
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
    final match = {
      'users': [user1.uid, user2.uid],
      'userNames': {user1.uid: user1.displayName, user2.uid: user2.displayName},
      'userPhotos': {user1.uid: user1.photoUrl, user2.uid: user2.photoUrl},
      'sparksScore': sparksScore,
      'tier': 1,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    };
    await ref.set(match);
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
    // Denormalize last message into match doc
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
```

---

## Step 4 — `lib/core/utils/juice_engine.dart`

Ensure `computeSparks` is a static method:

```dart
static double computeSparks(JuiceProfile a, JuiceProfile b) {
  final diff = (a.family - b.family).abs() +
      (a.career - b.career).abs() +
      (a.lifestyle - b.lifestyle).abs() +
      (a.ethics - b.ethics).abs() +
      (a.fun - b.fun).abs();
  return ((1 - diff / 5) * 100).clamp(0.0, 100.0);
}
```

---

## Step 5 — `lib/features/auth/login_screen.dart`

Wire Google Sign-In via `firebase_auth` + `google_sign_in`. On success, check if Firestore profile exists → route to `/quiz` (new user) or `/home` (returning user).

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/theme/juice_theme.dart';
import '../../core/network/firestore_service.dart';
import '../../widgets/juice_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  final _service = FirestoreService();

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user!;

      final existing = await _service.getUserOnce(user.uid);
      if (!mounted) return;
      if (existing == null) {
        Navigator.pushReplacementNamed(context, '/quiz');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Icon(Icons.favorite_rounded, size: 80, color: JuiceTheme.primaryTangerine),
            const SizedBox(height: 24),
            Text('Welcome to\nJuiceDates',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text(
              'Find someone who shares your values, not just your hobbies.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const Spacer(),
            JuiceButton(
              onPressed: () => Navigator.pushNamed(context, '/quiz'),
              text: 'Sign Up with Email',
              isGradient: true,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              OutlinedButton.icon(
                onPressed: _signInWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 30),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: JuiceTheme.primaryTangerine),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
```

---

## Step 6 — `lib/features/onboarding/profile_setup.dart`

Wire "Save & Continue" to `FirestoreService.createUser()` using the `JuiceProfile` passed as route argument from the quiz/summary flow. Add city and age text fields.

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/utils/juice_engine.dart';
import '../../models/user_models.dart';
import '../../widgets/juice_button.dart';
import '../../core/theme/juice_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _service = FirestoreService();
  final _cityController = TextEditingController(text: 'Kampala');
  final _ageController = TextEditingController(text: '25');
  bool _saving = false;

  Future<void> _saveProfile() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final profile =
        ModalRoute.of(context)?.settings.arguments as JuiceProfile? ??
            JuiceProfile(family: 0.5, career: 0.5, lifestyle: 0.5, ethics: 0.5, fun: 0.5);

    final scores = {
      'Family': profile.family,
      'Career': profile.career,
      'Lifestyle': profile.lifestyle,
      'Ethics': profile.ethics,
      'Fun': profile.fun,
    };
    final dominant = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final summary = '${dominant.key} Juice Master '
        '(${(scores.values.reduce((a, b) => a + b) / scores.length * 100).round()}%)';

    setState(() => _saving = true);
    try {
      final juiceUser = JuiceUser(
        uid: firebaseUser.uid,
        displayName: firebaseUser.displayName ?? 'JuiceUser',
        age: int.tryParse(_ageController.text.trim()) ?? 25,
        email: firebaseUser.email,
        photoUrl: firebaseUser.photoURL,
        photos: [],
        city: _cityController.text.trim(),
        juiceProfile: profile,
        juiceSummary: summary,
      );
      await _service.createUser(juiceUser);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add your best photos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: List.generate(6, (index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, color: Colors.grey),
                );
              }),
            ),
            const SizedBox(height: 32),
            const Text('Your Voice Juice',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Record a 10s intro to boost matching by 20%'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JuiceTheme.primaryTangerine.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic_rounded, color: JuiceTheme.primaryTangerine),
                  const SizedBox(width: 16),
                  const Text('Introduction Voice Note'),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.play_arrow_rounded), onPressed: () {}),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Where are you?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'City',
                prefixIcon: const Icon(Icons.location_on_rounded, color: JuiceTheme.primaryTangerine),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Your age',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Age',
                prefixIcon: const Icon(Icons.cake_rounded, color: JuiceTheme.primaryTangerine),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 48),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : JuiceButton(onPressed: _saveProfile, text: 'Save & Continue', isGradient: true),
          ],
        ),
      ),
    );
  }
}
```

---

## Step 7 — `lib/features/home/juice_feed_screen.dart`

Replace mock list with `FirestoreService.getFeedUsers()` stream. Wire right-swipe → `likeUser` (show match dialog on mutual), left-swipe → `passUser`.

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../core/network/firestore_service.dart';
import '../../models/user_models.dart';
import '../../widgets/juice_card.dart';

class JuiceFeedScreen extends StatefulWidget {
  const JuiceFeedScreen({super.key});

  @override
  State<JuiceFeedScreen> createState() => _JuiceFeedScreenState();
}

class _JuiceFeedScreenState extends State<JuiceFeedScreen> {
  final CardSwiperController _cardController = CardSwiperController();
  final _service = FirestoreService();
  List<JuiceUser> _feedUsers = [];
  JuiceUser? _currentUser;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _currentUser = await _service.getUserOnce(uid);
    _service.getFeedUsers(uid).listen((users) {
      if (mounted) setState(() { _feedUsers = users; _loading = false; });
    });
  }

  Future<bool> _onSwipe(
      int previousIndex, int? currentIndex, CardSwiperDirection direction) async {
    final swipedUser = _feedUsers[previousIndex];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _currentUser == null) return true;

    if (direction == CardSwiperDirection.right) {
      final match = await _service.likeUser(_currentUser!, swipedUser);
      if (match != null && mounted) _showMatchDialog(swipedUser);
    } else if (direction == CardSwiperDirection.left) {
      await _service.passUser(uid, swipedUser.uid);
    }
    return true;
  }

  void _showMatchDialog(JuiceUser other) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('It\'s a Juice Match! 🎉'),
        content: Text('You and ${other.displayName} both liked each other!\nStart a conversation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep Swiping')),
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pushNamed(context, '/home'); },
            child: const Text('Go to Matches'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() { _cardController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Juice Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.pushNamed(context, '/filters'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_feedUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_satisfied_alt_rounded, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('You\'ve seen everyone!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Check back later for new Juice matches.',
                style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return Center(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: CardSwiper(
          controller: _cardController,
          cardsCount: _feedUsers.length,
          allowedSwipeDirection: const AllowedSwipeDirection.all(),
          numberOfCardsDisplayed: _feedUsers.length >= 3 ? 3 : _feedUsers.length,
          backCardOffset: const Offset(0, 40),
          padding: const EdgeInsets.all(24.0),
          cardBuilder: (context, index, hOff, vOff) {
            final user = _feedUsers[index];
            return JuiceCard(user: {
              'name': user.displayName,
              'age': user.age,
              'city': user.city,
              'summary': user.juiceSummary,
              'sparks': user.juiceProfile.family * 100,
            });
          },
          onSwipe: _onSwipe,
          onEnd: () => setState(() => _feedUsers = []),
        ),
      ),
    );
  }
}
```

---

## Step 8 — `lib/features/matches/matches_list_screen.dart`

Replace const mock list with `StreamBuilder<List<JuiceMatch>>`. Show partner name/photo, sparks, tier, last-active time. Tap → `SingleChatScreen` with real `matchId`.

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../chat/single_chat_screen.dart';

class MatchesListScreen extends StatelessWidget {
  const MatchesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: StreamBuilder<List<JuiceMatch>>(
        stream: service.getMatches(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = snapshot.data ?? [];
          if (matches.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final match = matches[index];
              final partnerName = match.getPartnerName(uid);
              final photoUrl = match.getPartnerPhoto(uid);

              return Card(
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SingleChatScreen(name: partnerName, matchId: match.matchId),
                  )),
                  leading: CircleAvatar(
                    backgroundColor: JuiceTheme.primaryTangerine,
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  title: Text(partnerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Sparks: ${match.sparksScore.toStringAsFixed(0)}%'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_timeAgo(match.lastMessageTime),
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(4, (i) => Icon(
                          i < match.tier
                              ? Icons.battery_charging_full_rounded
                              : Icons.battery_alert_rounded,
                          size: 16,
                          color: i < match.tier ? JuiceTheme.juiceGreen : Colors.grey[300],
                        )),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No matches yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Keep swiping to find your Juice match!',
              style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
```

---

## Step 9 — `lib/features/chat/chat_list_screen.dart`

Replace const mock list with `StreamBuilder<List<JuiceMatch>>`. Show partner name/photo, `lastMessage`, tier badge, relative time. Tap → `SingleChatScreen` with real `matchId`.

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import 'single_chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: StreamBuilder<List<JuiceMatch>>(
        stream: service.getMatches(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = snapshot.data ?? [];
          if (matches.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final match = matches[index];
              final partnerName = match.getPartnerName(uid);
              final photoUrl = match.getPartnerPhoto(uid);

              return ListTile(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SingleChatScreen(name: partnerName, matchId: match.matchId),
                )),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: JuiceTheme.secondaryCitrus,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 30) : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: JuiceTheme.juiceGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Row(children: [
                  Text(partnerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  _buildTierBadge(match.tier),
                ]),
                subtitle: Text(
                  match.lastMessage.isEmpty ? 'Start a conversation!' : match.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(_timeAgo(match.lastMessageTime),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              );
            },
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildTierBadge(int tier) {
    const labels = {1: '💚', 2: '🧡', 3: '❤️', 4: '💎'};
    return Text(labels[tier] ?? '💚', style: const TextStyle(fontSize: 12));
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No chats yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Match with someone and start a conversation!',
              style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
```

---

## Step 10 — `lib/features/chat/single_chat_screen.dart`

Add required `matchId` parameter. Stream messages from Firestore subcollection. Send writes via `FirestoreService.sendMessage()` + updates `lastMessage` on match doc. Tier auto-advances locally every 10 sent messages + calls `updateMatchTier`.

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../../widgets/tier_meter.dart';
import '../calling/video_call_screen.dart';
import '../calling/audio_call_screen.dart';

class SingleChatScreen extends StatefulWidget {
  final String name;
  final String matchId;

  const SingleChatScreen({super.key, required this.name, required this.matchId});

  @override
  State<SingleChatScreen> createState() => _SingleChatScreenState();
}

class _SingleChatScreenState extends State<SingleChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _service = FirestoreService();
  late final String _myUid;
  int _currentTier = 1;
  double _progression = 0.0;
  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    _service.sendMessage(widget.matchId, JuiceMessage(
      senderId: _myUid,
      text: text,
      tierUnlocked: _currentTier,
      timestamp: DateTime.now(),
    ));

    setState(() {
      _messageCount++;
      _progression = (_messageCount % 10) / 10.0;
      if (_messageCount > 0 && _messageCount % 10 == 0) {
        final newTier = (_currentTier % 4) + 1;
        if (newTier > _currentTier) {
          _currentTier = newTier;
          _service.updateMatchTier(widget.matchId, _currentTier);
        }
      }
    });
  }

  @override
  void dispose() { _controller.dispose(); _scrollController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: JuiceTheme.primaryTangerine,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(widget.name, style: const TextStyle(fontSize: 18)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const VideoCallScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AudioCallScreen())),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: TierMeter(tier: _currentTier, progression: _progression),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<JuiceMessage>>(
              stream: _service.getMessages(widget.matchId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                if (messages.isNotEmpty) _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _myUid;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? JuiceTheme.primaryTangerine : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
                            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(0),
                          ),
                        ),
                        child: Text(msg.text,
                            style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.mic_rounded,
                color: _currentTier >= 2 ? Colors.orange : Colors.grey),
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: JuiceTheme.primaryTangerine),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
```

---

## Step 11 — `lib/features/events/juice_tribes_screen.dart`

Replace const mock list with `StreamBuilder<List<JuiceEvent>>`. Falls back to local seed data when Firestore `events` collection is empty. Tap → `EventDetailsScreen` with real `JuiceEvent`.

```dart
import 'package:flutter/material.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import 'event_details_screen.dart';

class JuiceTribesScreen extends StatelessWidget {
  const JuiceTribesScreen({super.key});

  static const _fallbackTribes = [
    {'id': 'local_1', 'title': 'Family First Picnic', 'category': 'Family',
      'date': 'Oct 24, 2026', 'attendees': 42, 'attendeeUids': <String>[], 'description': '', 'location': 'Kampala Central'},
    {'id': 'local_2', 'title': 'Startup Founders Mixer', 'category': 'Career',
      'date': 'Oct 26, 2026', 'attendees': 18, 'attendeeUids': <String>[], 'description': '', 'location': 'Kampala Central'},
    {'id': 'local_3', 'title': 'Sunset Yoga & Values', 'category': 'Lifestyle',
      'date': 'Oct 28, 2026', 'attendees': 35, 'attendeeUids': <String>[], 'description': '', 'location': 'Kampala Central'},
  ];

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Juice Tribes')),
      body: StreamBuilder<List<JuiceEvent>>(
        stream: service.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data ?? [];
          if (events.isEmpty) return _buildFallbackList(context);
          return _buildEventList(context, events);
        },
      ),
    );
  }

  Widget _buildFallbackList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fallbackTribes.length,
      itemBuilder: (context, index) {
        final t = Map<String, dynamic>.from(_fallbackTribes[index]);
        return _buildEventCard(context, JuiceEvent(
          id: t['id'] as String, title: t['title'] as String,
          category: t['category'] as String, date: t['date'] as String,
          attendees: t['attendees'] as int,
        ));
      },
    );
  }

  Widget _buildEventList(BuildContext context, List<JuiceEvent> events) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) => _buildEventCard(context, events[index]),
    );
  }

  Widget _buildEventCard(BuildContext context, JuiceEvent event) {
    final iconMap = {
      'Family': Icons.family_restroom_rounded, 'Career': Icons.business_center_rounded,
      'Lifestyle': Icons.self_improvement_rounded, 'Ethics': Icons.balance_rounded,
      'Fun': Icons.celebration_rounded,
    };

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => EventDetailsScreen(event: event))),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: JuiceTheme.primaryGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Icon(iconMap[event.category] ?? Icons.event_rounded, size: 60, color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: JuiceTheme.primaryTangerine.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(event.category, style: const TextStyle(
                            color: JuiceTheme.primaryTangerine, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const Spacer(),
                      Text(event.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(event.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.people_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${event.attendees} attending', style: const TextStyle(color: Colors.grey)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Step 12 — `lib/features/events/event_details_screen.dart`

Change parameter from `Map tribe` to `JuiceEvent event`. Wire RSVP toggle → `rsvpEvent` / `cancelRsvp`. Show live attendee count and RSVP state.

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../../widgets/juice_button.dart';

class EventDetailsScreen extends StatefulWidget {
  final JuiceEvent event;
  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final _service = FirestoreService();
  late bool _hasRsvped;
  late int _attendees;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _hasRsvped = widget.event.attendeeUids.contains(uid);
    _attendees = widget.event.attendees;
  }

  Future<void> _toggleRsvp() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      if (_hasRsvped) {
        await _service.cancelRsvp(widget.event.id, uid);
        setState(() { _hasRsvped = false; _attendees--; });
      } else {
        await _service.rsvpEvent(widget.event.id, uid);
        setState(() { _hasRsvped = true; _attendees++; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconMap = {
      'Family': Icons.family_restroom_rounded, 'Career': Icons.business_center_rounded,
      'Lifestyle': Icons.self_improvement_rounded, 'Ethics': Icons.balance_rounded,
      'Fun': Icons.celebration_rounded,
    };

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(gradient: JuiceTheme.primaryGradient),
                child: Icon(iconMap[widget.event.category] ?? Icons.event_rounded,
                    size: 80, color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _buildInfoChip(Icons.calendar_today_rounded, widget.event.date),
                    const SizedBox(width: 12),
                    _buildInfoChip(Icons.people_rounded, '$_attendees Joined'),
                  ]),
                  const SizedBox(height: 24),
                  const Text('About this Event',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    widget.event.description.isNotEmpty ? widget.event.description
                        : 'Join your fellow JuiceDates members who share similar values! '
                          'This event is designed to foster deep connections and '
                          'meaningful conversations in a relaxed environment.',
                    style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text('Location', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
                    child: Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.map_rounded, size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(widget.event.location, style: const TextStyle(color: Colors.grey)),
                      ],
                    )),
                  ),
                  const SizedBox(height: 32),
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : JuiceButton(
                          onPressed: _toggleRsvp,
                          text: _hasRsvped ? 'Cancel RSVP' : 'RSVP Now',
                          isGradient: !_hasRsvped,
                        ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: JuiceTheme.primaryTangerine.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: JuiceTheme.primaryTangerine),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
```

---

## Post-implementation checklist

- [ ] `flutter pub get` after adding `google_sign_in`
- [ ] Verify `JuiceEngine.computeSparks` is a `static` method
- [ ] Add `google-services.json` SHA-1 fingerprint to Firebase console for Google Sign-In
- [ ] Create Firestore composite index: `matches` → `users` (array-contains) + `lastMessageTime` (desc)
- [ ] Create Firestore composite index: `events` → `date` (asc)
- [ ] `flutter build apk --debug` then `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
