import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../core/network/firestore_service.dart';
import '../../core/utils/juice_engine.dart';
import '../../models/user_models.dart';
import '../../widgets/juice_card.dart';
import 'user_profile_screen.dart';

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
  String? _error;
  StreamSubscription<List<JuiceUser>>? _feedSub;
  // null = unlimited (premium), int = likes left today
  int? _likesRemaining;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() { _loading = true; _error = null; });
    await _feedSub?.cancel();
    _feedSub = null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      _currentUser = await _service.getUserOnce(uid);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
      return;
    }

    final isPremium = _currentUser?.isPremium ?? false;

    // Load daily likes info for free users
    final left = await _service.getDailyLikesLeft(uid, isPremium);
    if (mounted) setState(() => _likesRemaining = left);

    _feedSub = _service.getFeedUsers(uid, isPremium: isPremium).listen(
      (users) {
        if (mounted) setState(() { _feedUsers = users; _loading = false; });
      },
      onError: (e) {
        if (mounted) setState(() { _loading = false; _error = e.toString(); });
      },
    );
  }

  Future<bool> _onSwipe(
      int previousIndex, int? currentIndex, CardSwiperDirection direction) async {
    final swipedUser = _feedUsers[previousIndex];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _currentUser == null) return true;

    if (direction == CardSwiperDirection.right) {
      try {
        final match = await _service.likeUser(_currentUser!, swipedUser);
        if (match != null && mounted) _showMatchDialog(swipedUser);
        // Update remaining count for free users
        if (_likesRemaining != null && mounted) {
          setState(() => _likesRemaining = (_likesRemaining! - 1).clamp(0, 999));
        }
      } on DailyLimitException {
        if (mounted) _showDailyLimitDialog();
        return false; // don't advance the card
      }
    } else if (direction == CardSwiperDirection.left) {
      await _service.passUser(uid, swipedUser.uid);
    }
    return true;
  }

  void _showDailyLimitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Daily limit reached 🍊"),
        content: const Text(
            'You\'ve used all 50 free likes for today.\n\nUpgrade to Juice Plus+ for unlimited daily likes!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/premium-paywall');
            },
            child: const Text('Get Plus+', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMatchDialog(JuiceUser other) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("It's a Juice Match! 🎉"),
        content: Text(
            'You and ${other.displayName} both liked each other!\nStart a conversation.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Swiping')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/home');
              },
              child: const Text('Go to Matches')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Could not load feed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadFeed,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Free user exhausted daily likes
    if (_likesRemaining == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🍊', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text("You've used today's likes!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                  'Free accounts get 50 likes per day.\nCome back tomorrow or upgrade for unlimited.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                ),
                onPressed: () =>
                    Navigator.pushNamed(context, '/premium-paywall'),
                child: const Text('Get Juice Plus+',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (_feedUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_satisfied_alt_rounded,
                size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text("You've seen everyone!",
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Check back later for new Juice matches.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return Column(
      children: [
        // Likes-remaining banner for free users running low
        if (_likesRemaining != null && _likesRemaining! <= 10)
          Container(
            width: double.infinity,
            color: _likesRemaining! <= 3
                ? Colors.red[900]
                : Colors.orange[900],
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('❤️', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_likesRemaining like${_likesRemaining == 1 ? '' : 's'} left today — tap to upgrade',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/premium-paywall'),
                  child: const Text('Plus+',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        Expanded(
          child: CardSwiper(
            controller: _cardController,
            cardsCount: _feedUsers.length,
            allowedSwipeDirection: const AllowedSwipeDirection.all(),
            numberOfCardsDisplayed:
                _feedUsers.length >= 3 ? 3 : _feedUsers.length,
            backCardOffset: const Offset(0, 40),
            padding: const EdgeInsets.all(24.0),
            cardBuilder: (context, index, hOff, vOff) {
              final user = _feedUsers[index];
              final sparks = _currentUser != null
                  ? JuiceEngine.computeSparks(
                      _currentUser!.juiceProfile, user.juiceProfile)
                  : 0.0;
              return JuiceCard(
                user: user,
                sparksScore: sparks,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      user: user,
                      sparksScore: sparks,
                    ),
                  ),
                ),
              );
            },
            onSwipe: _onSwipe,
            onEnd: () => setState(() => _feedUsers = []),
          ),
        ),
      ],
    );
  }
}
