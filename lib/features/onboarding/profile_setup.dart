import 'package:flutter/material.dart';
import '../../widgets/juice_button.dart';
import '../../core/theme/juice_theme.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add your best photos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: List.generate(6, (index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, color: Colors.grey),
                );
              }),
            ),
            const SizedBox(height: 32),
            const Text(
              'Your Voice Juice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Record a 10s intro to boost matching by 20%'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JuiceTheme.primaryTangerine.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic_rounded, color: JuiceTheme.primaryTangerine),
                  const SizedBox(width: 16),
                  const Text('Introduction Voice Note'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Where are you?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.location_on_rounded, color: JuiceTheme.primaryTangerine),
              title: const Text('Detect City (One-time)'),
              subtitle: const Text('Kampala, Uganda'),
              trailing: const Icon(Icons.refresh_rounded),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            const SizedBox(height: 48),
            JuiceButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              text: 'Save & Continue',
              isGradient: true,
            ),
          ],
        ),
      ),
    );
  }
}
