import 'package:flutter/material.dart';
import '../../core/network/firestore_service.dart';
import '../../core/theme/juice_theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 700;
      final padding = isWide ? 32.0 : 16.0;
      return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'Overview',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, int>>(
            future: service.getAdminStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()));
              }
              final stats = snapshot.data ?? {};
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWide ? 4 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: isWide ? 1.4 : 1.2,
                children: [
                  _StatCard(
                      label: 'Total Users',
                      value: '${stats['users'] ?? 0}',
                      icon: Icons.people_rounded,
                      color: Colors.blue),
                  _StatCard(
                      label: 'Matches Made',
                      value: '${stats['matches'] ?? 0}',
                      icon: Icons.favorite_rounded,
                      color: JuiceTheme.primaryTangerine),
                  _StatCard(
                      label: 'Open Reports',
                      value: '${stats['reports'] ?? 0}',
                      icon: Icons.flag_rounded,
                      color: Colors.orange),
                  _StatCard(
                      label: 'Events',
                      value: '${stats['events'] ?? 0}',
                      icon: Icons.event_rounded,
                      color: JuiceTheme.juiceGreen),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Quick Actions',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isWide ? 200 : double.infinity,
                child: _QuickActionCard(
                  icon: Icons.person_search_rounded,
                  label: 'View Users',
                  color: Colors.blue,
                ),
              ),
              SizedBox(
                width: isWide ? 200 : double.infinity,
                child: _QuickActionCard(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Add Event',
                  color: JuiceTheme.juiceGreen,
                ),
              ),
              SizedBox(
                width: isWide ? 200 : double.infinity,
                child: _QuickActionCard(
                  icon: Icons.flag_rounded,
                  label: 'Review Reports',
                  color: Colors.orange,
                ),
              ),
              SizedBox(
                width: isWide ? 200 : double.infinity,
                child: _QuickActionCard(
                  icon: Icons.campaign_rounded,
                  label: 'Send Announcement',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
    });
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
