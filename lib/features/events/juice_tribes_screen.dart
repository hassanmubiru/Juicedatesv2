import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';
import 'event_details_screen.dart';

class JuiceTribesScreen extends StatelessWidget {
  const JuiceTribesScreen({super.key});

  final List<Map<String, dynamic>> _tribes = const [
    {
      'title': 'Family First Picnic',
      'category': 'Family',
      'date': 'Oct 24, 2026',
      'attendees': 42,
      'image': Icons.family_restroom_rounded,
    },
    {
      'title': 'Startup Founders Mixer',
      'category': 'Career',
      'date': 'Oct 26, 2026',
      'attendees': 18,
      'image': Icons.business_center_rounded,
    },
    {
      'title': 'Sunset Yoga & Values',
      'category': 'Lifestyle',
      'date': 'Oct 28, 2026',
      'attendees': 35,
      'image': Icons.self_improvement_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Juice Tribes')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tribes.length,
        itemBuilder: (context, index) {
          final tribe = _tribes[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EventDetailsScreen(tribe: tribe)),
              );
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: JuiceTheme.primaryGradient,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Icon(tribe['image'] as IconData, size: 60, color: Colors.white),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: JuiceTheme.primaryTangerine.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tribe['category'],
                                style: const TextStyle(color: JuiceTheme.primaryTangerine, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const Spacer(),
                            Text(tribe['date'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(tribe['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.people_rounded, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${tribe['attendees']} attending', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
