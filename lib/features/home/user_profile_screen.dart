import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../core/utils/juice_engine.dart';
import '../../models/user_models.dart';

class UserProfileScreen extends StatefulWidget {
  final JuiceUser user;
  final double sparksScore;

  const UserProfileScreen({
    super.key,
    required this.user,
    this.sparksScore = 0,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final PageController _pageController = PageController();
  int _currentPhotoIndex = 0;

  List<String> get _photos {
    final photos = [...widget.user.photos];
    if (photos.isEmpty && widget.user.photoUrl != null) {
      photos.add(widget.user.photoUrl!);
    }
    return photos;
  }

  @override
  void initState() {
    super.initState();
    // Record that current user viewed this profile
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null) {
      FirestoreService().recordProfileView(myUid, widget.user.uid);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final photos = _photos;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: JuiceTheme.backgroundWhite,
      bottomNavigationBar: _WinkBar(targetUser: user),
      body: CustomScrollView(
        slivers: [
          // ── Photo gallery ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: screenHeight * 0.55,
            pinned: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // PageView photo gallery
                  photos.isNotEmpty
                      ? PageView.builder(
                          controller: _pageController,
                          itemCount: photos.length,
                          onPageChanged: (i) =>
                              setState(() => _currentPhotoIndex = i),
                          itemBuilder: (ctx, i) {
                            return CachedNetworkImage(
                              imageUrl: photos[i],
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => Container(
                                color: Colors.black,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                ),
                              ),
                              errorWidget: (ctx, url, err) =>
                                  _buildPhotoPlaceholder(user),
                            );
                          },
                        )
                      : _buildPhotoPlaceholder(user),

                  // Photo count dots
                  if (photos.length > 1)
                    Positioned(
                      top: 56,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          photos.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _currentPhotoIndex ? 24 : 7,
                            height: 4,
                            decoration: BoxDecoration(
                              color: i == _currentPhotoIndex
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Bottom gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Name / age overlay
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                user.showAge
                                    ? '${user.displayName}, ${user.age}'
                                    : user.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                        blurRadius: 8,
                                        color: Colors.black54)
                                  ],
                                ),
                              ),
                            ),
                            if (widget.sparksScore >= 60)
                              _SparksBadge(score: widget.sparksScore),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: Colors.white70, size: 15),
                            const SizedBox(width: 4),
                            Text(
                              user.city,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                        // Job / company line
                        if ((user.jobTitle != null && user.jobTitle!.isNotEmpty) ||
                            (user.company != null && user.company!.isNotEmpty)) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.work_outline_rounded,
                                  color: Colors.white60, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  [
                                    if (user.jobTitle != null && user.jobTitle!.isNotEmpty)
                                      user.jobTitle!,
                                    if (user.company != null && user.company!.isNotEmpty)
                                      'at ${user.company!}',
                                  ].join(' '),
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        // University line
                        if (user.university != null && user.university!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.school_outlined,
                                  color: Colors.white60, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  user.university!,
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Profile details ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Juice Summary pill
                  _SectionCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: JuiceTheme.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_fire_department_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            user.juiceSummary.isNotEmpty
                                ? user.juiceSummary
                                : 'No juice profile yet',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: JuiceTheme.textDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bio
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const _SectionLabel(label: 'About'),
                    const SizedBox(height: 8),
                    _SectionCard(
                      child: Text(
                        user.bio!,
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: JuiceTheme.textDark),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Interests
                  if (user.interests.isNotEmpty) ...[
                    const _SectionLabel(label: 'Interests'),
                    const SizedBox(height: 8),
                    _SectionCard(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: user.interests
                            .map((interest) => _InterestChip(label: interest))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Juice Profile Breakdown
                  const _SectionLabel(label: 'Juice Profile'),
                  const SizedBox(height: 8),
                  _SectionCard(
                    child: _JuiceProfileBreakdown(
                        profile: user.juiceProfile),
                  ),
                  const SizedBox(height: 16),

                  // Premium badge
                  if (user.isPremium)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: JuiceTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text('Juice Plus+ Member',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder(JuiceUser user) {
    return Container(
      decoration: BoxDecoration(gradient: JuiceTheme.primaryGradient),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_rounded, size: 100, color: Colors.white54),
            const SizedBox(height: 8),
            Text(
              user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontSize: 64,
                  color: Colors.white60,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────

class _SparksBadge extends StatelessWidget {
  final double score;
  const _SparksBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: JuiceTheme.juiceGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flash_on_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 3),
          Text(
            '${score.round()}%',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;
  const _InterestChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            JuiceTheme.primaryTangerine.withValues(alpha: 0.15),
            JuiceTheme.secondaryCitrus.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: JuiceTheme.primaryTangerine.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 13,
            color: JuiceTheme.primaryTangerine,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _JuiceProfileBreakdown extends StatelessWidget {
  final JuiceProfile profile;
  const _JuiceProfileBreakdown({required this.profile});

  @override
  Widget build(BuildContext context) {
    final traits = [
      ('Family Values', profile.family),
      ('Career Drive', profile.career),
      ('Lifestyle', profile.lifestyle),
      ('Ethics', profile.ethics),
      ('Fun Factor', profile.fun),
    ];
    return Column(
      children: traits
          .map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TraitRow(label: t.$1, ratio: t.$2),
              ))
          .toList(),
    );
  }
}

class _WinkBar extends StatefulWidget {
  final JuiceUser targetUser;
  const _WinkBar({required this.targetUser});

  @override
  State<_WinkBar> createState() => _WinkBarState();
}

class _WinkBarState extends State<_WinkBar> {
  bool _winkSent = false;
  final _service = FirestoreService();

  Future<void> _sendWink() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    final myUser = await _service.getUserOnce(myUid);
    if (myUser == null || !mounted) return;
    await _service.winkUser(
      myUid,
      myUser.displayName,
      myUser.photoUrl,
      widget.targetUser.uid,
    );
    if (!mounted) return;
    setState(() => _winkSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wink sent to ${widget.targetUser.displayName}! 👋'),
        backgroundColor: JuiceTheme.primaryTangerine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Text('👋', style: TextStyle(fontSize: 18)),
            label: Text(
              _winkSent ? 'Wink Sent!' : 'Send a Wink',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _winkSent
                      ? Colors.grey
                      : JuiceTheme.primaryTangerine),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: _winkSent
                      ? Colors.grey
                      : JuiceTheme.primaryTangerine,
                  width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _winkSent ? null : _sendWink,
          ),
        ),
      ),
    );
  }
}

class _TraitRow extends StatelessWidget {
  final String label;
  final double ratio; // 0.0 – 1.0
  const _TraitRow({required this.label, required this.ratio});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 13, color: JuiceTheme.textDark)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  JuiceTheme.primaryTangerine),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(ratio * 100).round()}%',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: JuiceTheme.primaryTangerine)),
      ],
    );
  }
}
