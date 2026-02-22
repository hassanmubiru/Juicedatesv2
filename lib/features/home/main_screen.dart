import 'package:flutter/material.dart';
import 'package:juicedates/features/home/juice_feed_screen.dart';
import 'package:juicedates/features/matches/matches_list_screen.dart';
import 'package:juicedates/features/chat/chat_list_screen.dart';
import 'package:juicedates/features/events/juice_tribes_screen.dart';
import 'package:juicedates/core/theme/juice_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const JuiceFeedScreen(),
    const MatchesListScreen(),
    const ChatListScreen(),
    const JuiceTribesScreen(),
  ];

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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded, color: JuiceTheme.primaryTangerine),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: JuiceTheme.primaryTangerine),
            label: 'Matches',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded, color: JuiceTheme.primaryTangerine),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded, color: JuiceTheme.primaryTangerine),
            label: 'Tribes',
          ),
        ],
      ),
    );
  }
}
