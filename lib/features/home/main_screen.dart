import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:juicedates/core/network/firestore_service.dart';
import 'package:juicedates/features/home/juice_feed_screen.dart';
import 'package:juicedates/features/matches/matches_list_screen.dart';
import 'package:juicedates/features/chat/chat_list_screen.dart';
import 'package:juicedates/features/notifications/notifications_screen.dart';
import 'package:juicedates/features/premium/settings_screen.dart';
import 'package:juicedates/core/theme/juice_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _unreadCount = 0;

  final List<Widget> _screens = [
    const JuiceFeedScreen(),
    const MatchesListScreen(),
    const NotificationsScreen(),
    const ChatListScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _listenUnread();
  }

  void _listenUnread() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirestoreService().getUnreadMatchCount(uid).listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        indicatorColor: JuiceTheme.primaryTangerine.withValues(alpha: 0.15),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded,
                color: JuiceTheme.primaryTangerine),
            label: 'Feed',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded,
                color: JuiceTheme.primaryTangerine),
            label: 'Matches',
          ),
          // Notifications tab with unread badge
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.notifications_rounded,
                  color: JuiceTheme.primaryTangerine),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded,
                color: JuiceTheme.primaryTangerine),
            label: 'Chats',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded,
                color: JuiceTheme.primaryTangerine),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
