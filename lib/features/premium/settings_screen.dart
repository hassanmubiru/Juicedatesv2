import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../blocs/auth_bloc.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';
import '../../main.dart' show themeModeNotifier;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = false;
  bool _isAdmin = false;
  bool _isPremium = false;
  bool _invisibleMode = true;
  bool _newSparks = true;
  int _profileViewCount = 0;

  @override
  void initState() {
    super.initState();
    _isDark = themeModeNotifier.value == ThemeMode.dark;
    _loadPrefs();
    _loadAdminStatus();
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

  Future<void> _loadAdminStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await FirestoreService().getUserOnce(uid);
    if (mounted && user != null) {
      setState(() {
        _isAdmin = user.isAdmin;
        _isPremium = user.isPremium;
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

  Future<void> _clearGpsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_city');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS cache cleared.')),
      );
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
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
            subtitle: const Text('Get a verified badge'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon('Juice Verification'),
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
          const SizedBox(height: 12),
          if (_isAdmin) ...[
            const _SectionHeader(title: 'Admin'),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: JuiceTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded,
                    color: Colors.white, size: 20),
              ),
              title: const Text('Admin Panel',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Manage users, reports & events'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/admin'),
            ),
          ],
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
              child: Text('v1.0.6 (JuiceDates Beta)',
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
