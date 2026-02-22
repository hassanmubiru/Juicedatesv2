import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';

class MatchesListScreen extends StatelessWidget {
  const MatchesListScreen({super.key});

  final List<Map<String, dynamic>> _matches = const [
    {'name': 'Sarah', 'sparks': 92, 'tier': 2, 'lastActive': '2m ago'},
    {'name': 'Elena', 'sparks': 88, 'tier': 1, 'lastActive': '1h ago'},
    {'name': 'Grace', 'sparks': 82, 'tier': 1, 'lastActive': '3h ago'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: _matches.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _matches.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final match = _matches[index];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: JuiceTheme.primaryTangerine,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                match['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Sparks potential: ${match['sparks']}%'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(match['lastActive'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(4, (i) {
                      return Icon(
                        i < match['tier'] ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
                        size: 16,
                        color: i < match['tier'] ? JuiceTheme.juiceGreen : Colors.grey[300],
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No matches yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Keep swiping to find your Juice match!',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
