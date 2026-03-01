import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';
import 'admin_dashboard.dart';
import 'admin_users_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_events_screen.dart';
import 'admin_notifications_screen.dart';

const _kWideBreakpoint = 700.0;

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  void _setTab(int index) => setState(() => _currentIndex = index);

  late final List<Widget> _screens = [
    AdminDashboardScreen(onNavigateTo: _setTab),
    const AdminUsersScreen(),
    const AdminReportsScreen(),
    const AdminEventsScreen(),
    const AdminNotificationsScreen(),
  ];

  static const _labels = ['Dashboard', 'Users', 'Reports', 'Events', 'Notify'];
  static const _icons = [
    Icons.dashboard_rounded,
    Icons.people_rounded,
    Icons.flag_rounded,
    Icons.event_rounded,
    Icons.campaign_rounded,
  ];

  Widget _adminBadge() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          Text(_labels[_currentIndex]),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= _kWideBreakpoint;

      if (isWide) {
        // ── Wide / Web layout: NavigationRail sidebar ──────────────────────
        return Scaffold(
          appBar: AppBar(
            title: _adminBadge(),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => setState(() {}),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: (i) =>
                    setState(() => _currentIndex = i),
                labelType: NavigationRailLabelType.all,
                leading: const SizedBox(height: 8),
                destinations: List.generate(
                  _labels.length,
                  (i) => NavigationRailDestination(
                    icon: Icon(_icons[i]),
                    label: Text(_labels[i]),
                  ),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
        );
      }

      // ── Narrow / Mobile layout: bottom NavigationBar ───────────────────
      return Scaffold(
        appBar: AppBar(
          title: _adminBadge(),
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
          destinations: List.generate(
            _labels.length,
            (i) => NavigationDestination(
              icon: Icon(_icons[i]),
              label: _labels[i],
            ),
          ),
        ),
      );
    });
  }
}
