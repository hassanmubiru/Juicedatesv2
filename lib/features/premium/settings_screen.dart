import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../blocs/auth_bloc.dart';
import '../../core/network/cloudinary_service.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../models/user_models.dart';
import '../../main.dart' show themeModeNotifier;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = false;
  bool _isPremium = false;
  bool _invisibleMode = true;
  bool _newSparks = true;
  bool _showAge = true;
  int _profileViewCount = 0;
  JuiceUser? _user;

  @override
  void initState() {
    super.initState();
    _isDark = themeModeNotifier.value == ThemeMode.dark;
    _loadPrefs();
    _loadUserStatus();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _invisibleMode = prefs.getBool('invisibleMode') ?? false;
        _newSparks = prefs.getBool('newSparks') ?? true;
      });
    }
  }

  Future<void> _loadUserStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await FirestoreService().getUserOnce(uid);
    if (mounted && user != null) {
      setState(() {
        _isPremium = user.isPremium;
        _showAge = user.showAge;
        _user = user;
      });
    }
    // Load profile view count (non-blocking)
    final viewCount = await FirestoreService().getProfileViewCount(uid);
    if (mounted) setState(() => _profileViewCount = viewCount);
  }

  Future<void> _toggleDark(bool val) async {
    setState(() => _isDark = val);
    themeModeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', val);
  }

  Future<void> _toggleInvisible(bool val) async {
    setState(() => _invisibleMode = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('invisibleMode', val);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirestoreService().updateUserProfile(uid, {'invisibleMode': val});
    }
  }

  Future<void> _toggleSparks(bool val) async {
    setState(() => _newSparks = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('newSparks', val);
  }

  Future<void> _toggleShowAge(bool val) async {
    setState(() => _showAge = val);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirestoreService().updateUserProfile(uid, {'showAge': val});
    }
  }

  Future<void> _clearGpsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_city');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS cache cleared.')),
      );
    }
  }

  Future<void> _inviteFriends() async {
    await Share.share(
      '❤️ Join me on JuiceDates — a values-first dating app with an 85% reply rate!\n\nDownload it here: https://juicedates.app',
      subject: 'Join JuiceDates',
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your profile, matches, and all data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirestoreService().deleteAccount(uid);
    await FirebaseAuth.instance.currentUser?.delete();
    if (mounted) {
      context.read<AuthBloc>().add(AuthLoggedOut());
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(feature),
        content: const Text('This feature is coming soon! Stay tuned for updates.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showVerificationFlow() async {
    final verificationStatus = _user?.verificationStatus;
    if (verificationStatus == 'verified') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your profile is already verified ✅')),
      );
      return;
    }
    if (verificationStatus == 'pending') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Your verification request is under review. Check back soon!')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _VerificationSheet(
        user: _user!,
        onSubmitted: () {
          // Reload user from Firestore to reflect the pending status
          _loadUserStatus();
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Profile Strength card ──────────────────────────────────────────
          if (_user != null) _ProfileStrengthCard(user: _user!),
          const _SectionHeader(title: 'Account Settings'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/edit-profile'),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Juice Verification'),
            subtitle: Text(
              _user?.verificationStatus == 'verified'
                  ? 'Verified ✅'
                  : _user?.verificationStatus == 'pending'
                      ? 'Under review…'
                      : 'Get a verified badge',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _user == null ? null : _showVerificationFlow,
          ),
          // Profile views
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.visibility_rounded,
                  color: Colors.blue, size: 20),
            ),
            title: const Text('Profile Views'),
            subtitle: Text(
              _profileViewCount == 0
                  ? 'No views yet this week'
                  : '$_profileViewCount ${_profileViewCount == 1 ? 'person' : 'people'} viewed your profile this week',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon('Detailed Viewers'),
          ),
          const _SectionHeader(title: 'Premium'),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: _isPremium ? JuiceTheme.primaryGradient : null,
                color: _isPremium ? null : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isPremium ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _isPremium ? Colors.white : JuiceTheme.primaryTangerine,
                size: 20,
              ),
            ),
            title: const Text('Juice Plus+'),
            subtitle: Text(
              _isPremium ? 'Active — all perks unlocked' : 'Unlock Spark Filters & more',
            ),
            trailing: _isPremium
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: JuiceTheme.primaryTangerine.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: JuiceTheme.primaryTangerine,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/premium-paywall'),
          ),
          const _SectionHeader(title: 'Privacy & Safety'),
          SwitchListTile(
            value: _isDark,
            onChanged: _toggleDark,
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          SwitchListTile(
            value: _invisibleMode,
            onChanged: _toggleInvisible,
            title: const Text('Invisible Mode'),
            subtitle: const Text('Hide your online status'),
            secondary: const Icon(Icons.visibility_off_outlined),
          ),
          SwitchListTile(
            value: _showAge,
            onChanged: _toggleShowAge,
            title: const Text('Show My Age'),
            subtitle: const Text('Display age on your profile card'),
            secondary: const Icon(Icons.cake_outlined),
          ),
          ListTile(
            leading: const Icon(Icons.location_off_outlined),
            title: const Text('Clear GPS Cache'),
            subtitle: const Text('Remove saved location data'),
            onTap: _clearGpsCache,
          ),
          const _SectionHeader(title: 'Notifications'),
          SwitchListTile(
            value: _newSparks,
            onChanged: _toggleSparks,
            title: const Text('New Sparks'),
            subtitle: const Text('Notify me when I get a new match'),
            secondary: const Icon(Icons.flash_on_rounded),
          ),
          const _SectionHeader(title: 'Community'),
          ListTile(
            leading: const Icon(Icons.people_alt_outlined),
            title: const Text('Invite Friends'),
            subtitle: const Text('Share JuiceDates with people you know'),
            trailing: const Icon(Icons.share_rounded),
            onTap: _inviteFriends,
          ),
          const _SectionHeader(title: 'Danger Zone'),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: const Text('Delete Account',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently remove your account and data'),
            onTap: _deleteAccount,
          ),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () {
                context.read<AuthBloc>().add(AuthLoggedOut());
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false);
              },
              child: const Text('Logout',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ),
          const Center(
              child: Text('v1.0.7 (JuiceDates Beta)',
                  style: TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1),
      ),
    );
  }
}

/// Profile completion strength card — shown at the top of the settings/profile tab.
class _ProfileStrengthCard extends StatelessWidget {
  final JuiceUser user;
  const _ProfileStrengthCard({required this.user});

  /// Returns a 0–100 strength score and a list of missing field hints.
  static ({int score, List<String> missing}) _compute(JuiceUser u) {
    final checks = <(bool, String)>[
      (u.photos.isNotEmpty, 'Add a profile photo'),
      (u.photos.length >= 3, 'Add 3+ photos'),
      (u.bio != null && u.bio!.trim().length > 20, 'Write a bio'),
      (u.interests.length >= 3, 'Add 3+ interests'),
      (u.university != null && u.university!.isNotEmpty, 'Add your university'),
      (u.jobTitle != null && u.jobTitle!.isNotEmpty, 'Add your job title'),
      (u.sexualOrientation != null, 'Set sexual orientation'),
      (u.bio != null && u.bio!.trim().isNotEmpty, 'Write something in your bio'),
      (u.juiceProfile.family > 0, 'Complete the Juice Quiz'),
      (u.city != 'Unknown' && u.city.isNotEmpty, 'Set your city'),
    ];
    final total = checks.length;
    final done = checks.where((c) => c.$1).length;
    final missing = checks
        .where((c) => !c.$1)
        .map((c) => c.$2)
        .toList();
    return (score: (done * 100 ~/ total), missing: missing.take(3).toList());
  }

  @override
  Widget build(BuildContext context) {
    final result = _compute(user);
    final score = result.score;
    final missing = result.missing;
    final color = score >= 80
        ? JuiceTheme.juiceGreen
        : score >= 50
            ? JuiceTheme.primaryTangerine
            : Colors.red.shade400;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: JuiceTheme.primaryTangerine),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Profile Strength',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Text('$score%',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100.0,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...missing.map((hint) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(hint,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
                        ],
                      ),
                    )),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/edit-profile'),
                  child: Text(
                    'Complete your profile →',
                    style: TextStyle(
                        color: JuiceTheme.primaryTangerine,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text('Your profile is complete! 🎉',
                    style: TextStyle(
                        color: JuiceTheme.juiceGreen,
                        fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
