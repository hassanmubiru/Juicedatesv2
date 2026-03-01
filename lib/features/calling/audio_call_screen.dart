import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';

class AudioCallScreen extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const AudioCallScreen({super.key, this.name = 'Unknown', this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JuiceTheme.primaryTangerine,
      body: Container(
        decoration: BoxDecoration(gradient: JuiceTheme.primaryGradient),
        child: Column(
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white24,
              backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                  ? NetworkImage(photoUrl!)
                  : null,
              child: photoUrl == null || photoUrl!.isEmpty
                  ? const Icon(Icons.person, size: 70, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Voice Juice Active...',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  10,
                  (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 40 + (i % 3 * 20).toDouble(),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAction(Icons.mic_off_rounded),
                _buildAction(Icons.call_end_rounded,
                    color: Colors.red,
                    onTap: () => Navigator.pop(context)),
                _buildAction(Icons.volume_up_rounded),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon,
      {Color color = Colors.white24, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JuiceTheme.primaryTangerine,
      body: Container(
        decoration: BoxDecoration(gradient: JuiceTheme.primaryGradient),
        child: Column(
          children: [
            const Spacer(),
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 70, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sarah',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Voice Juice Active...',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const Spacer(),
            // Animated Waveform Placeholder
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(10, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 40 + (i % 3 * 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAction(Icons.mic_off_rounded),
                _buildAction(Icons.call_end_rounded,
                    color: Colors.red, onTap: () => Navigator.pop(context)),
                _buildAction(Icons.volume_up_rounded),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon, {Color color = Colors.white24, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
