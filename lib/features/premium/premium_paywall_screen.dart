import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';

class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  bool _isPremium = false;
  bool _requested = false;
  bool _loading = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await FirestoreService().getUserOnce(uid);
    if (mounted) {
      setState(() {
        _isPremium = user?.isPremium ?? false;
        _requested = user?.premiumRequested ?? false;
        _loading = false;
      });
    }
  }

  Future<void> _requestPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _requesting = true);
    await FirestoreService().requestPremium(uid);
    if (mounted) {
      setState(() {
        _requested = true;
        _requesting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent! Admin will review and activate your Plus+.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            JuiceTheme.primaryTangerine,
                            const Color(0xFFFF6B35),
                            const Color(0xFFFFD700),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Juice Plus+',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isPremium
                                  ? 'Your premium is active 🎉'
                                  : 'Find your match faster',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isPremium) ...[
                          _ActiveBanner(),
                          const SizedBox(height: 24),
                        ],
                        const Text(
                          'What\'s included',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PerkTile(
                          icon: Icons.tune_rounded,
                          title: 'Advanced Spark Filters',
                          description:
                              'Filter by values, lifestyle, distance and more to find your ideal match.',
                          active: _isPremium,
                        ),
                        _PerkTile(
                          icon: Icons.favorite_rounded,
                          title: 'See Who Liked You',
                          description:
                              'View your full likes list instantly — no more guessing.',
                          active: _isPremium,
                        ),
                        _PerkTile(
                          icon: Icons.all_inclusive_rounded,
                          title: 'Unlimited Daily Likes',
                          description:
                              'No daily limits — like as many profiles as you want.',
                          active: _isPremium,
                        ),
                        _PerkTile(
                          icon: Icons.visibility_off_rounded,
                          title: 'Invisible Mode',
                          description:
                              'Browse profiles without appearing in the feed.',
                          active: _isPremium,
                        ),
                        _PerkTile(
                          icon: Icons.rocket_launch_rounded,
                          title: 'Priority in Feed',
                          description:
                              'Your profile is shown first to potential matches.',
                          active: _isPremium,
                        ),
                        _PerkTile(
                          icon: Icons.mark_chat_read_rounded,
                          title: 'Read Receipts',
                          description:
                              'Know exactly when your messages are read.',
                          active: _isPremium,
                        ),
                        const SizedBox(height: 32),
                        if (!_isPremium) ...[
                          _requested
                              ? _RequestedCard()
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30)),
                                      backgroundColor:
                                          JuiceTheme.primaryTangerine,
                                    ),
                                    onPressed:
                                        _requesting ? null : _requestPremium,
                                    child: _requesting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Get Juice Plus+',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                          const SizedBox(height: 12),
                          const Center(
                            child: Text(
                              'Beta access — activation by admin review',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Active banner ────────────────────────────────────────────────────────
class _ActiveBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            JuiceTheme.primaryTangerine.withValues(alpha: 0.1),
            const Color(0xFFFFD700).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: JuiceTheme.primaryTangerine.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded,
              color: JuiceTheme.primaryTangerine, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Juice Plus+ Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: JuiceTheme.primaryTangerine,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'All premium features are unlocked for you.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Request sent card ────────────────────────────────────────────────────
class _RequestedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: Colors.blue),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request sent!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Admin will review and activate your Plus+ soon.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Perk list tile ───────────────────────────────────────────────────────
class _PerkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool active;
  const _PerkTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: active
                  ? JuiceTheme.primaryTangerine.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: active ? JuiceTheme.primaryTangerine : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: active ? null : Colors.grey,
                        ),
                      ),
                    ),
                    if (active)
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 18),
                    if (!active)
                      const Icon(Icons.lock_outline_rounded,
                          color: Colors.grey, size: 16),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
