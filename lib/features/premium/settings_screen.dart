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

  @override
  void initState() {
    super.initState();
    _isDark = themeModeNotifier.value == ThemeMode.dark;
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await FirestoreService().getUserOnce(uid);
    if (mounted && user != null) {
      setState(() => _isAdmin = user.isAdmin);
    }
  }

  Future<void> _toggleDark(bool val) async {
    setState(() => _isDark = val);
    themeModeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', val);
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
          const _SectionHeader(title: 'Privacy & Safety'),
          SwitchListTile(
            value: _isDark,
            onChanged: _toggleDark,
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode_outlined),
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
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ),
          const Center(child: Text('v1.0.0 (JuiceDates Alpha)', style: TextStyle(color: Colors.grey, fontSize: 12))),
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
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
      ),
    );
  }
}
