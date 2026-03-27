import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../core/utils/juice_engine.dart';
import '../../models/user_models.dart';
import '../../widgets/juice_card.dart';
import 'user_profile_screen.dart';
import '../moments/moments_bar.dart';
import '../boost/boost_screen.dart';
import 'top_picks_screen.dart';

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
  // null = unlimited (premium), int = super likes left today
  int? _superLikesRemaining;
  // Undo support
  JuiceUser? _lastSwipedUser;
  CardSwiperDirection? _lastSwipeDirection;

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

    // Load daily likes + super likes info
    final left = await _service.getDailyLikesLeft(uid, isPremium);
    final superLeft = await _service.getSuperLikesLeft(uid, isPremium);
    if (mounted) setState(() { _likesRemaining = left; _superLikesRemaining = superLeft; });

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
    // Remember for undo
    _lastSwipedUser = swipedUser;
    _lastSwipeDirection = direction;
    return true;
  }

  Future<void> _onSuperLike() async {
    if (_feedUsers.isEmpty || _currentUser == null) return;
    final swipedUser = _feedUsers[0];
    try {
      final match = await _service.superLikeUser(_currentUser!, swipedUser);
      if (match != null && mounted) _showMatchDialog(swipedUser);
      if (_superLikesRemaining != null && mounted) {
        setState(() =>
            _superLikesRemaining = (_superLikesRemaining! - 1).clamp(0, 99));
      }
      _cardController.swipe(CardSwiperDirection.top);
    } on DailyLimitException {
      if (mounted) _showDailyLimitDialog(isSuperLike: true);
    }
  }

  bool _onUndoSwipe(
      int? previousIndex, int currentIndex, CardSwiperDirection direction) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _lastSwipedUser == null) return true;
    final undoneUser = _lastSwipedUser!;
    final undoneDirection = _lastSwipeDirection;

    // Consistency: If it was a like, we must also remove the potential match doc
    if (undoneDirection == CardSwiperDirection.right) {
      _service.removePotentialMatch(uid, undoneUser.uid);
    }

    // Fire-and-forget Firestore reversal
    if (undoneDirection == CardSwiperDirection.left) {
      _service.updateUserProfile(uid, {
        'passedUids': FieldValue.arrayRemove([undoneUser.uid]),
      });
    } else if (undoneDirection == CardSwiperDirection.right) {
      _service.updateUserProfile(uid, {
        'likedUids': FieldValue.arrayRemove([undoneUser.uid]),
      });
      if (_likesRemaining != null && mounted) {
        setState(() => _likesRemaining = _likesRemaining! + 1);
      }
    }
    if (mounted) setState(() { _lastSwipedUser = null; _lastSwipeDirection = null; });
    return true;
  }

  void _showDailyLimitDialog({bool isSuperLike = false}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _JuiceLimitDialog(isSuperLike: isSuperLike),
    );
  }

  void _showMatchDialog(JuiceUser other) {
    if (_currentUser == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _JuiceMatchDialog(
        me: _currentUser!,
        other: other,
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
          // Top Picks button
          IconButton(
            icon: const Icon(Icons.local_fire_department_rounded),
            tooltip: 'Top Picks',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TopPicksScreen()),
            ),
          ),
          // Boost button
          IconButton(
            icon: const Icon(Icons.bolt_rounded),
            tooltip: 'Boost',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BoostScreen()),
            ),
          ),
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
        // 24-hour Moments story bar (hookup4u-inspired)
        const MomentsBar(),
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
            onUndo: _onUndoSwipe,
            onEnd: () => setState(() => _feedUsers = []),
          ),
        ),
        // ── Action buttons: Pass / Super Like / Like ───────────────────────
        _buildActionButtons(),
      ],
    );
  }

  // ── Pass / Super Like / Like buttons ──────────────────────────────────
  Widget _buildActionButtons() {
    final disabled = _feedUsers.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Rewind ↩
          _FeedActionBtn(
            heroTag: 'undo_btn',
            icon: Icons.replay_rounded,
            color: Colors.amber.shade600,
            diameter: 48,
            onTap: _lastSwipedUser == null
                ? null
                : () => _cardController.undo(),
          ),
          // Pass ✕
          _FeedActionBtn(
            heroTag: 'pass_btn',
            icon: Icons.close_rounded,
            color: Colors.red.shade400,
            diameter: 58,
            onTap: disabled
                ? null
                : () => _cardController.swipe(CardSwiperDirection.left),
          ),
          // Super Like ⭐ (smaller, with remaining count badge)
          _FeedActionBtn(
            heroTag: 'super_btn',
            icon: Icons.star_rounded,
            color: Colors.blue.shade400,
            diameter: 48,
            badge: _superLikesRemaining,
            onTap: disabled ? null : _onSuperLike,
          ),
          // Like ❤
          _FeedActionBtn(
            heroTag: 'like_btn',
            icon: Icons.favorite_rounded,
            color: JuiceTheme.primaryTangerine,
            diameter: 58,
            onTap: disabled
                ? null
                : () => _cardController.swipe(CardSwiperDirection.right),
          ),
        ],
      ),
    );
  }
}

// ── Action button widget ────────────────────────────────────────────────
class _FeedActionBtn extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final Color color;
  final double diameter;
  final int? badge; // null = unlimited, shows no badge
  final VoidCallback? onTap;

  const _FeedActionBtn({
    required this.heroTag,
    required this.icon,
    required this.color,
    required this.diameter,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final btn = FloatingActionButton(
      heroTag: heroTag,
      onPressed: onTap,
      backgroundColor: Colors.white,
      elevation: onTap == null ? 0 : 5,
      child: Icon(
        icon,
        color: onTap == null ? Colors.grey[300] : color,
        size: diameter * 0.5,
      ),
    );
    if (badge == null) return SizedBox(width: diameter, height: diameter, child: btn);
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          btn,
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Premium Dialogs ──────────────────────────────────────────────────

class _JuiceMatchDialog extends StatelessWidget {
  final JuiceUser me;
  final JuiceUser other;

  const _JuiceMatchDialog({required this.me, required this.other});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: JuiceTheme.matchGradient,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "IT'S A MATCH!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You and ${other.displayName} have squeezed a connection!",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circularAvatar(me.photoUrl),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.favorite_rounded, color: Colors.white, size: 40),
                ),
                _circularAvatar(other.photoUrl),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: JuiceTheme.primaryTangerine,
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/home'); // Matches tab
              },
              child: const Text("SAY HELLO", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("KEEP SWIPING", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circularAvatar(String? url) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        image: url != null
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: url == null ? const Icon(Icons.person, color: Colors.white) : null,
    );
  }
}

class _JuiceLimitDialog extends StatelessWidget {
  final bool isSuperLike;

  const _JuiceLimitDialog({required this.isSuperLike});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🍊", style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              isSuperLike ? "Super Limit Reached" : "Daily Limit Reached",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              isSuperLike
                  ? "You've used all 3 Super Likes for today. upgrade for unlimited!"
                  : "You've used all 50 free likes for today. Upgrade to Juice Plus+ for unlimited likes!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JuiceTheme.primaryTangerine,
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/premium-paywall');
              },
              child: const Text("GET JUICE PLUS+", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("MAYBE LATER", style: TextStyle(color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }
}
