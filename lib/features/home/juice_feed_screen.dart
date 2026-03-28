import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../core/utils/juice_engine.dart';
import '../../models/user_models.dart';
import '../../widgets/juice_card.dart';
import 'user_profile_screen.dart';
import '../moments/moments_bar.dart';
import '../boost/boost_screen.dart';
import '../../widgets/profile_nudge_card.dart';
import '../../features/premium/settings_screen.dart';
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      _currentUser = await _service.getUserOnce(uid);
      if (_currentUser == null) throw Exception('User not found');
      
      final isPremium = _currentUser!.isPremium;

      // Load daily likes + super likes info
      final left = await _service.getDailyLikesLeft(uid, isPremium);
      final superLeft = await _service.getSuperLikesLeft(uid, isPremium);
      if (mounted) {
        setState(() { _likesRemaining = left; _superLikesRemaining = superLeft; });
      }

      final users = await _service.getFeedUsers(uid, limit: 60, isPremium: isPremium);
      
      // Inject profile nudge card if profile strength < 80%
      if (mounted && _currentUser != null && users.isNotEmpty) {
        final strength = JuiceEngine.computeProfileStrength(_currentUser!);
        if (strength.score < 80) {
          // Special virtual user ID to signal cardBuilder to show the nudge
          final nudgeUser = JuiceUser(
            uid: 'profile_nudge',
            displayName: 'Juice Progress',
            photos: [],
            city: '',
            juiceProfile: JuiceProfile(family: 0, career: 0, lifestyle: 0, ethics: 0, fun: 0),
            juiceSummary: '',
          );
          users.insert(users.length >= 2 ? 1 : 0, nudgeUser);
        }
      }

      if (mounted) {
        setState(() {
          _feedUsers = users;
          _loading = false;
        });
        _precacheNextImages();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _precacheNextImages() {
    if (!mounted) return;
    for (int i = 0; i < 3 && i < _feedUsers.length; i++) {
      final url = _feedUsers[i].photoUrl;
      if (url != null && url.isNotEmpty) precacheImage(NetworkImage(url), context);
    }
  }

  void _precacheNextIndex(int currentIndex) {
    if (!mounted) return;
    // Cache the card 2 steps ahead to guarantee it's loaded before we reach it
    if (currentIndex + 2 < _feedUsers.length) {
      final url = _feedUsers[currentIndex + 2].photoUrl;
      if (url != null && url.isNotEmpty) precacheImage(NetworkImage(url), context);
    }
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
        if (_likesRemaining != null && mounted) {
          setState(() => _likesRemaining = (_likesRemaining! - 1).clamp(0, 999));
        }
      } on DailyLimitException {
        if (mounted) _showDailyLimitDialog();
        return false; // don't advance the card
      }
    } else if (direction == CardSwiperDirection.top) {
      try {
        final match = await _service.superLikeUser(_currentUser!, swipedUser);
        if (match != null && mounted) _showMatchDialog(swipedUser);
        if (_superLikesRemaining != null && mounted) {
          setState(() => _superLikesRemaining = (_superLikesRemaining! - 1).clamp(0, 99));
        }
        // Show celebratory animation
        if (mounted) _showSuperLikeOverlay();
      } on DailyLimitException {
        if (mounted) _showDailyLimitDialog(isSuperLike: true);
        return false;
      }
    } else if (direction == CardSwiperDirection.left) {
      await _service.passUser(uid, swipedUser.uid);
    }
    
    // Physical feedback
    if (direction == CardSwiperDirection.top) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    // Remember for undo
    _lastSwipedUser = swipedUser;
    _lastSwipeDirection = direction;
    
    if (currentIndex != null) _precacheNextIndex(currentIndex);
    return true;
  }

  bool _onUndoSwipe(
      int? previousIndex, int currentIndex, CardSwiperDirection direction) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _lastSwipedUser == null || _currentUser == null) return true;
    final undoneUser = _lastSwipedUser!;
    final undoneDirection = _lastSwipeDirection;
    final isPremium = _currentUser!.isPremium;

    // Delegate undo backend cleanup to FirestoreService
    if (undoneDirection == CardSwiperDirection.left) {
      _service.undoSwipe(uid, undoneUser.uid, 'pass', isPremium);
    } else if (undoneDirection == CardSwiperDirection.right) {
      _service.undoSwipe(uid, undoneUser.uid, 'like', isPremium);
      if (_likesRemaining != null && mounted) {
        setState(() => _likesRemaining = _likesRemaining! + 1);
      }
    } else if (undoneDirection == CardSwiperDirection.top) {
      _service.undoSwipe(uid, undoneUser.uid, 'superlike', isPremium);
      if (_likesRemaining != null && mounted) {
        setState(() => _likesRemaining = _likesRemaining! + 1);
      }
      if (_superLikesRemaining != null && mounted) {
        setState(() => _superLikesRemaining = _superLikesRemaining! + 1);
      }
    }
    
    if (mounted) setState(() { _lastSwipedUser = null; _lastSwipeDirection = null; });
    return true;
  }

  Future<void> _resetDiscovery() async {
    if (_currentUser == null) return;
    setState(() => _loading = true);
    try {
      // Reset current user filters in Firestore
      await _service.updateDiscoveryFilters(
        uid: _currentUser!.uid,
        ageMin: 18,
        ageMax: 80,
        showGender: 'everyone',
        distance: 50,
      );
      // Wait for it to settle then reload
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadFeed();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
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
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.mediumImpact());
  }

  void _showSuperLikeOverlay() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _SuperLikeAnimation(),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  Widget _buildDiscoveryHeader() {
    if (_currentUser == null) return const SizedBox.shrink();
    final isPassport = _currentUser!.passportCity != null;
    final city = _currentUser!.passportCity ?? _currentUser!.city;
    final gender = _currentUser!.showGender == 'everyone'
        ? 'Everyone'
        : _currentUser!.showGender == 'men'
            ? 'Men'
            : 'Women';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPassport ? Colors.blue.withOpacity(0.1) : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: isPassport ? Border.all(color: Colors.blue.withOpacity(0.3)) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPassport ? Icons.flight_takeoff_rounded : Icons.location_on_rounded,
                  color: isPassport ? Colors.blue : Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  city,
                  style: TextStyle(
                    color: isPassport ? Colors.blue : Colors.white,
                  ),
                ),
                Container(width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white24),
                Text(
                  '$gender • ${_currentUser!.ageRangeMin}-${_currentUser!.ageRangeMax}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
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
          // Boost button (with active indicator if running)
          Builder(builder: (ctx) {
            final now = DateTime.now();
            final active = _currentUser?.boostExpiresAt != null &&
                _currentUser!.boostExpiresAt!.isAfter(now);
            return Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active) ...[
                      StreamBuilder<int>(
                        stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
                        builder: (context, _) {
                          final rem = _currentUser!.boostExpiresAt!.difference(DateTime.now());
                          if (rem.isNegative) return const SizedBox.shrink();
                          final m = rem.inMinutes.remainder(60);
                          final s = rem.inSeconds.remainder(60).toString().padLeft(2, '0');
                          return Text(
                            '$m:$s',
                            style: const TextStyle(
                              color: JuiceTheme.primaryTangerine,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: Icon(
                        Icons.bolt_rounded,
                        color: active ? JuiceTheme.primaryTangerine : null,
                      ),
                      tooltip: 'Boost',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BoostScreen()),
                        );
                        _loadFeed(); // Refresh user status (boost could be active now)
                      },
                    ),
                  ],
                ),
                if (active)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: JuiceTheme.primaryTangerine,
                          shape: BoxShape.circle),
                    ),
                  ),
              ],
            );
          }),
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
      return Center(
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
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _resetDiscovery,
              icon: Icon(Icons.refresh_rounded),
              label: Text('RESET DISCOVERY', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: JuiceTheme.primaryTangerine,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        // 24-hour Moments story bar (hookup4u-inspired)
        const MomentsBar(),
        // Discovery status chip
        _buildDiscoveryHeader(),
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
              
              if (user.uid == 'profile_nudge') {
                return ProfileNudgeCard(
                  user: _currentUser!,
                  score: JuiceEngine.computeProfileStrength(_currentUser!).score,
                  missing: JuiceEngine.computeProfileStrength(_currentUser!).missing,
                  onComplete: () => Navigator.pushNamed(context, '/edit-profile'),
                );
              }

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
            onTap: disabled ? null : () => _cardController.swipe(CardSwiperDirection.top),
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white38),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    JuiceEngine.getStrongestSharedValue(me.juiceProfile, other.juiceProfile),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
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

// ── Super Like Animation Overlay ───────────────────────────────────────────

class _SuperLikeAnimation extends StatefulWidget {
  const _SuperLikeAnimation();

  @override
  State<_SuperLikeAnimation> createState() => _SuperLikeAnimationState();
}

class _SuperLikeAnimationState extends State<_SuperLikeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.4),
                    blurRadius: 50,
                    spreadRadius: 20,
                  )
                ],
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Colors.blue,
                size: 160,
                shadows: [Shadow(color: Colors.black26, blurRadius: 20)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

