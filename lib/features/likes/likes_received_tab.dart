import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../home/user_profile_screen.dart';

/// Shows a grid of users who liked the current user.
/// Free users see blurred faces + a count with an upgrade CTA.
/// Premium users see clear faces with instant Match / Pass buttons.
class LikesReceivedTab extends StatefulWidget {
  const LikesReceivedTab({super.key});

  @override
  State<LikesReceivedTab> createState() => _LikesReceivedTabState();
}

class _LikesReceivedTabState extends State<LikesReceivedTab> {
  final _service = FirestoreService();
  String? _uid;
  bool _isPremium = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid == null) return;
    final user = await _service.getUserOnce(_uid!);
    if (mounted) {
      setState(() {
        _isPremium = user?.isPremium ?? false;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _uid == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<List<JuiceUser>>(
      stream: _service.getUsersWhoLikedMe(_uid!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final likers = snapshot.data ?? [];
        if (likers.isEmpty) return _buildEmpty();
        return _isPremium
            ? _buildPremiumGrid(likers)
            : _buildLockedView(likers);
      },
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🍊', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text('No likes yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Keep swiping — your perfect match is out there!',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Free: blurred faces + upgrade CTA ───────────────────────────────────
  Widget _buildLockedView(List<JuiceUser> likers) {
    return Stack(
      children: [
        IgnorePointer(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.88,
            ),
            itemCount: likers.length,
            itemBuilder: (_, i) {
              final url = likers[i].photos.isNotEmpty
                  ? likers[i].photos.first
                  : likers[i].photoUrl ?? '';
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: url.isNotEmpty
                      ? Image.network(url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: JuiceTheme.primaryTangerine
                                  .withValues(alpha: 0.4)))
                      : Container(
                          decoration: BoxDecoration(
                              gradient: JuiceTheme.primaryGradient)),
                ),
              );
            },
          ),
        ),
        // Gradient scrim
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.88),
                ],
                begin: const FractionalOffset(0, 0.3),
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        // CTA
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: Column(
            children: [
              Text(
                '${likers.length} ${likers.length == 1 ? 'person' : 'people'} liked you',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Upgrade to Juice Plus+ to see who they are\nand match instantly — no swiping needed.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: JuiceTheme.primaryTangerine,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/premium-paywall'),
                  child: const Text(
                    'See Who Liked You 🍊',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Premium: clear grid with Match / Pass buttons ─────────────────────────
  Widget _buildPremiumGrid(List<JuiceUser> likers) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      itemCount: likers.length,
      itemBuilder: (context, i) {
        final liker = likers[i];
        final url = liker.photos.isNotEmpty
            ? liker.photos.first
            : liker.photoUrl;
        return GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => UserProfileScreen(user: liker))),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Photo
                url != null && url.isNotEmpty
                    ? Image.network(url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                                gradient: JuiceTheme.primaryGradient),
                            child: const Icon(Icons.person,
                                color: Colors.white, size: 60)))
                    : Container(
                        decoration:
                            BoxDecoration(gradient: JuiceTheme.primaryGradient),
                        child: const Icon(Icons.person,
                            color: Colors.white, size: 60),
                      ),
                // Bottom info + buttons
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.90),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${liker.displayName}, ${liker.age}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                        if (liker.city.isNotEmpty)
                          Text(liker.city,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _GridBtn(
                                label: 'Pass',
                                color: Colors.white24,
                                textColor: Colors.white,
                                onTap: () async {
                                  await _service.passUser(_uid!, liker.uid);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Passed on ${liker.displayName}')),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _GridBtn(
                                label: '❤️ Match',
                                color: JuiceTheme.primaryTangerine,
                                textColor: Colors.white,
                                onTap: () async {
                                  final myUser =
                                      await _service.getUserOnce(_uid!);
                                  if (myUser == null) return;
                                  try {
                                    final match = await _service
                                        .likeUser(myUser, liker);
                                    if (!mounted) return;
                                    if (match != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "It's a match with ${liker.displayName}! 🎉")),
                                      );
                                    }
                                  } on DailyLimitException {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Daily limit reached. Upgrade to Plus+!')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GridBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _GridBtn({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12),
        ),
      ),
    );
  }
}
