import 'package:flutter/material.dart';
import 'package:flutter_tindercard/flutter_tindercard.dart';
import '../../core/theme/juice_theme.dart';
import '../../widgets/juice_card.dart';

class JuiceFeedScreen extends StatefulWidget {
  const JuiceFeedScreen({super.key});

  @override
  State<JuiceFeedScreen> createState() => _JuiceFeedScreenState();
}

class _JuiceFeedScreenState extends State<JuiceFeedScreen> {
  CardController controller = CardController();

  final List<Map<String, dynamic>> _mockUsers = [
    {
      'name': 'Sarah',
      'age': 24,
      'city': 'Kampala',
      'summary': 'Family Juice Master (85%)',
      'sparks': 92,
    },
    {
      'name': 'James',
      'age': 28,
      'city': 'Kampala',
      'summary': 'Adventure Seeker (70%)',
      'sparks': 75,
    },
    {
      'name': 'Elena',
      'age': 26,
      'city': 'Kampala',
      'summary': 'Career Driven (80%)',
      'sparks': 88,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Juice Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: TinderSwapCard(
            swipeUp: true,
            swipeDown: true,
            orientation: AmassOrientation.BOTTOM,
            totalNum: _mockUsers.length,
            stackNum: 3,
            swipeEdge: 4.0,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            minWidth: MediaQuery.of(context).size.width * 0.8,
            minHeight: MediaQuery.of(context).size.height * 0.7,
            cardBuilder: (context, index) {
              return JuiceCard(user: _mockUsers[index]);
            },
            cardController: controller,
            swipeUpdateCallback: (details, align) {
              if (align.x < 0) {
                // Left swipe
              } else if (align.x > 0) {
                // Right swipe
              }
            },
            swipeCompleteCallback: (orientation, index) {
              // Handle completion
            },
          ),
        ),
      ),
    );
  }
}
