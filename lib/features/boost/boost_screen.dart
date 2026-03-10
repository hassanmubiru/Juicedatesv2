import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../widgets/juice_button.dart';

class BoostScreen extends StatefulWidget {
  const BoostScreen({super.key});

  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _isPremium = false;
  bool _boostActive = false;
  DateTime? _boostExpiresAt;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  late final AnimationController _pulseCtrl;

  final _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.85,
      upperBound: 1.0,
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await _service.getUserOnce(uid);
    if (!mounted) return;
    final now = DateTime.now();
    final active = user?.boostExpiresAt != null &&
        user!.boostExpiresAt!.isAfter(now);
    setState(() {
      _isPremium = user?.isPremium ?? false;
      _boostActive = active;
      _boostExpiresAt = user?.boostExpiresAt;
      _loading = false;
    });
    if (active) _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_boostExpiresAt == null) return;
      final rem = _boostExpiresAt!.difference(DateTime.now());
      if (rem.isNegative) {
        _timer?.cancel();
        if (mounted) setState(() { _boostActive = false; _remaining = Duration.zero; });
      } else {
        if (mounted) setState(() => _remaining = rem);
      }
    });
  }

  Future<void> _activateBoost() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _service.boostUser(uid);
    final expiresAt = DateTime.now().add(const Duration(minutes: 30));
    if (mounted) {
      setState(() {
        _boostActive = true;
        _boostExpiresAt = expiresAt;
        _remaining = const Duration(minutes: 30);
      });
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚀 Boost activated! Your profile is on top for 30 min.'),
          backgroundColor: JuiceTheme.primaryTangerine,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Boost')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // ── Animated lightning bolt ──────────────────────────────────────
          ScaleTransition(
            scale: _boostActive ? _pulseCtrl : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _boostActive
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFFFAA00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade300, Colors.grey.shade400],
                      ),
                boxShadow: _boostActive
                    ? [
                        BoxShadow(
                          color: JuiceTheme.primaryTangerine.withValues(alpha: 0.5),
                          blurRadius: 32,
                          spreadRadius: 4,
                        )
                      ]
                    : [],
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 64),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _boostActive ? 'Boost Active!' : 'Profile Boost',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_boostActive) ...[
            Text(
              _formatRemaining(_remaining),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: JuiceTheme.primaryTangerine,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'minutes remaining',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ] else
            const Text(
              'Be seen by up to 10× more people for 30 minutes.\nYour profile appears at the top of everyone\'s feed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
            ),
          const SizedBox(height: 40),
          // ── Perks list ───────────────────────────────────────────────────
          if (!_boostActive) ...[
            _buildPerk(Icons.visibility_rounded, '10× more views',
                'Your profile is served first to nearby users'),
            _buildPerk(Icons.favorite_rounded, 'More likes',
                'Show up before everyone else in their feed'),
            _buildPerk(Icons.timer_rounded, '30 minutes',
                'Automatically expires after 30 minutes'),
            const SizedBox(height: 40),
          ],
          // ── CTA ──────────────────────────────────────────────────────────
          if (!_isPremium)
            Column(
              children: [
                const Text(
                  'Boost is a Juice Plus+ feature.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 16),
                JuiceButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/premium-paywall'),
                  text: 'Upgrade to Juice Plus+',
                  isGradient: true,
                ),
              ],
            )
          else if (!_boostActive)
            JuiceButton(
              onPressed: _activateBoost,
              text: '⚡  Activate Boost',
              isGradient: true,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: JuiceTheme.primaryTangerine.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: JuiceTheme.primaryTangerine.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded,
                      color: JuiceTheme.primaryTangerine, size: 20),
                  SizedBox(width: 8),
                  Text('Your boost is running',
                      style: TextStyle(
                          color: JuiceTheme.primaryTangerine,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildPerk(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: JuiceTheme.primaryTangerine.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: JuiceTheme.primaryTangerine, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
