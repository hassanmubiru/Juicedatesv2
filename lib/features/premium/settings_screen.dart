import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../blocs/auth_bloc.dart';
import '../../core/theme/juice_theme.dart';
import '../../../main.dart' show themeModeNotifier;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _isDark = themeModeNotifier.value == ThemeMode.dark;
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
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Juice Verification'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const _SectionHeader(title: 'Premium'),
          ListTile(
            leading: const Icon(Icons.star_outline, color: JuiceTheme.primaryTangerine),
            title: const Text('Juice Plus+'),
            subtitle: const Text('Unlock Video Calls & Spark Filters'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const _SectionHeader(title: 'Privacy & Safety'),
          SwitchListTile(
            value: _isDark,
            onChanged: _toggleDark,
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          SwitchListTile(
            value: true,
            onChanged: (v) {},
            title: const Text('Invisible Mode'),
            secondary: const Icon(Icons.visibility_off_outlined),
          ),
          ListTile(
            leading: const Icon(Icons.location_off_outlined),
            title: const Text('Clear GPS Cache'),
            onTap: () {},
          ),
          const _SectionHeader(title: 'Notifications'),
          SwitchListTile(
            value: true,
            onChanged: (v) {},
            title: const Text('New Sparks'),
            secondary: const Icon(Icons.flash_on_rounded),
          ),
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
