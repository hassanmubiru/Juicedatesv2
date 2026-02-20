import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            onTap: () {},
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
              onPressed: () {},
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
