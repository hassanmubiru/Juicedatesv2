import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';
import '../../widgets/juice_button.dart';

class PremiumFiltersScreen extends StatelessWidget {
  const PremiumFiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sparks Filters')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildFilterGroup('Core Values', ['Family Focused', 'Career Driven', 'Lifestyle Match']),
              const SizedBox(height: 24),
              _buildFilterGroup('Distance', ['Anywhere', '50km', '10km']),
              const SizedBox(height: 24),
              _buildFilterGroup('Advanced', ['Voice Only', 'Video Ready', 'Verified']),
            ],
          ),
          // Locked Overlay
          Container(
            color: Colors.white.withOpacity(0.8),
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(32),
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, size: 60, color: JuiceTheme.primaryTangerine),
                      const SizedBox(height: 24),
                      const Text(
                        'Unlock Sparks Filters',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '85% of people find their perfect match faster with premium juice.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      JuiceButton(
                        onPressed: () {},
                        text: 'Get Juice Plus+',
                        isGradient: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterGroup(String title, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: options.map((opt) => Chip(label: Text(opt))).toList(),
        ),
      ],
    );
  }
}
