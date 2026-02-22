import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';
import '../../core/utils/juice_engine.dart';
import '../../widgets/juice_button.dart';

class JuiceSummaryScreen extends StatelessWidget {
  const JuiceSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Receive the computed JuiceProfile from the quiz screen.
    final profile = ModalRoute.of(context)?.settings.arguments as JuiceProfile? ??
        JuiceProfile(family: 0.9, career: 0.6, lifestyle: 0.8, ethics: 0.7, fun: 0.5);

    // Derive a dominant category title.
    final scores = {
      'Family': profile.family,
      'Career': profile.career,
      'Lifestyle': profile.lifestyle,
      'Ethics': profile.ethics,
      'Fun': profile.fun,
    };
    final dominant = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final overallStrength = (scores.values.reduce((a, b) => a + b) / scores.length * 100).round();
    final dominantTitle = '${dominant.key} Juice Master';

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
                    boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 20)],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.stars_rounded, size: 60, color: JuiceTheme.secondaryCitrus),
                      const SizedBox(height: 16),
                      Text(
                        dominantTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: JuiceTheme.primaryTangerine),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$overallStrength% Core Strength',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      _buildStatRow('Family 🌿', profile.family),
                      _buildStatRow('Career 💼', profile.career),
                      _buildStatRow('Lifestyle ☀️', profile.lifestyle),
                      _buildStatRow('Ethics ⚖️', profile.ethics),
                      _buildStatRow('Fun 🎉', profile.fun),
                    ],
                  ),
                ),
                const Spacer(),
                JuiceButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    '/profile-setup',
                    arguments: profile,
                  ),
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
