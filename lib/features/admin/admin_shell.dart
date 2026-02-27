import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';
import 'admin_dashboard.dart';
import 'admin_users_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_events_screen.dart';
import 'admin_notifications_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  final _screens = const [
    AdminDashboardScreen(),
    AdminUsersScreen(),
    AdminReportsScreen(),
    AdminEventsScreen(),
    AdminNotificationsScreen(),
  ];

  final _titles = ['Dashboard', 'Users', 'Reports', 'Events', 'Notify'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: JuiceTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('ADMIN',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Text(_titles[_currentIndex]),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.people_rounded), label: 'Users'),
          NavigationDestination(
              icon: Icon(Icons.flag_rounded), label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.event_rounded), label: 'Events'),
          NavigationDestination(
              icon: Icon(Icons.campaign_rounded), label: 'Notify'),
        ],
      ),
    );
  }
}
