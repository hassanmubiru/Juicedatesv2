import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../core/theme/juice_theme.dart';
import '../../widgets/juice_card.dart';

class JuiceFeedScreen extends StatefulWidget {
  const JuiceFeedScreen({super.key});

  @override
  State<JuiceFeedScreen> createState() => _JuiceFeedScreenState();
}

class _JuiceFeedScreenState extends State<JuiceFeedScreen> {
  final CardSwiperController controller = CardSwiperController();

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
  void dispose() {
    controller.dispose();
    super.dispose();
  }

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
          child: CardSwiper(
            controller: controller,
            cardsCount: _mockUsers.length,
            allowedSwipeDirection: const AllowedSwipeDirection.all(),
            numberOfCardsDisplayed: 3,
            backCardOffset: const Offset(0, 40),
            padding: const EdgeInsets.all(24.0),
            cardBuilder: (context, index, horizontalOffsetPercentage,
                verticalOffsetPercentage) {
              return JuiceCard(user: _mockUsers[index]);
            },
            onSwipe: (previousIndex, currentIndex, direction) {
              if (direction == CardSwiperDirection.left) {
                // Left swipe — pass
              } else if (direction == CardSwiperDirection.right) {
                // Right swipe — like
              }
              return true; // return false to cancel the swipe
            },
            onEnd: () {
              // All cards have been swiped
            },
          ),
        ),
      ),
    );
  }
}
