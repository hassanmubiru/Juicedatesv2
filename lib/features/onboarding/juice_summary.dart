import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';
import '../../widgets/juice_button.dart';

class JuiceSummaryScreen extends StatelessWidget {
  const JuiceSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: JuiceTheme.primaryGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const Spacer(),
                const Text(
                  'Your Juice Profile',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Based on your core values',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.stars_rounded, size: 60, color: JuiceTheme.secondaryCitrus),
                      const SizedBox(height: 16),
                      Text(
                        'Family Juice Master',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: JuiceTheme.primaryTangerine),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '85% Core Strength',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      _buildStatRow('Family', 0.9),
                      _buildStatRow('Career', 0.6),
                      _buildStatRow('Lifestyle', 0.8),
                      _buildStatRow('Ethics', 0.7),
                    ],
                  ),
                ),
                const Spacer(),
                JuiceButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/profile-setup'),
                  text: 'Define My Profile',
                  isGradient: false,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, double val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${(val * 100).toInt()}%'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: val,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation(JuiceTheme.secondaryCitrus),
          ),
        ],
      ),
    );
  }
}
