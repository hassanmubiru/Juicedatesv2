import 'package:flutter/material.dart';
import '../core/theme/juice_theme.dart';

class TierMeter extends StatelessWidget {
  final int tier;
  final double progression;

  const TierMeter({super.key, required this.tier, required this.progression});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tier $tier ${_getTierEmoji(tier)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('${(progression * 100).toInt()}% to next tier', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progression,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(_getTierColor(tier)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(int tier) {
    switch (tier) {
      case 1: return JuiceTheme.juiceGreen;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      case 4: return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _getTierEmoji(int tier) {
    switch (tier) {
      case 1: return '💚';
      case 2: return '🧡';
      case 3: return '❤️';
      case 4: return '💎';
      default: return '💚';
    }
  }
}
