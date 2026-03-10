import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../core/utils/juice_engine.dart';
import '../../models/user_models.dart';
import '../../widgets/juice_button.dart';
import 'user_profile_screen.dart';

class TopPicksScreen extends StatefulWidget {
  const TopPicksScreen({super.key});

  @override
  State<TopPicksScreen> createState() => _TopPicksScreenState();
}

class _TopPicksScreenState extends State<TopPicksScreen> {
  bool _loading = true;
  bool _isPremium = false;
  List<JuiceUser> _picks = [];
  JuiceUser? _currentUser;

  final _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await _service.getUserOnce(uid);
    if (!mounted) return;
    if (user?.isPremium ?? false) {
      final picks = await _service.getTopPicks(uid);
      if (mounted) {
        setState(() {
          _isPremium = true;
          _currentUser = user;
          _picks = picks;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() { _isPremium = false; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.local_fire_department_rounded,
                color: JuiceTheme.primaryTangerine),
            SizedBox(width: 8),
            Text('Top Picks'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isPremium
              ? _buildPicks()
              : _buildLocked(),
    );
  }

  Widget _buildPicks() {
    if (_picks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No top picks today',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Check back tomorrow for new curated matches!',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's Top Picks",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_picks.length} curated high-compatibility profiles, just for you',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _picks.length,
            itemBuilder: (context, i) {
              final user = _picks[i];
              final sparks = _currentUser != null
                  ? JuiceEngine.computeSparks(
                      _currentUser!.juiceProfile, user.juiceProfile)
                  : 0.0;
              return _TopPickCard(user: user, sparksScore: sparks);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocked() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: JuiceTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_fire_department_rounded,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 28),
            const Text(
              'Top Picks',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'See up to 10 highly compatible matches handpicked for you every day — exclusive to Juice Plus+.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 40),
            JuiceButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/premium-paywall'),
              text: 'Get Juice Plus+',
              isGradient: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopPickCard extends StatelessWidget {
  final JuiceUser user;
  final double sparksScore;

  const _TopPickCard({required this.user, required this.sparksScore});

  @override
  Widget build(BuildContext context) {
    final photo =
        user.photos.isNotEmpty ? user.photos.first : user.photoUrl;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              UserProfileScreen(user: user, sparksScore: sparksScore),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo background
            photo != null && photo.isNotEmpty
                ? Image.network(photo, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            // Name + score
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.showAge
                        ? '${user.displayName}, ${user.age}'
                        : user.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: JuiceTheme.juiceGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.flash_on_rounded,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '${sparksScore.round()}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Top Picks fire badge
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: JuiceTheme.primaryTangerine,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(gradient: JuiceTheme.primaryGradient),
      child: const Center(
        child: Icon(Icons.person_rounded, size: 60, color: Colors.white54),
      ),
    );
  }
}
