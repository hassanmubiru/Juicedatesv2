import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';

class VideoCallScreen extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const VideoCallScreen({super.key, this.name = 'Unknown', this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video Placeholder
          Center(
            child: photoUrl != null && photoUrl!.isNotEmpty
                ? Image.network(photoUrl!, fit: BoxFit.cover,
                    width: double.infinity, height: double.infinity)
                : Icon(Icons.person, size: 200,
                    color: Colors.white.withValues(alpha: 0.1)),
          ),
          // Local Video Preview
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.videocam_rounded, color: Colors.white24),
            ),
          ),
          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallAction(Icons.mic_none_rounded, Colors.white24),
                _buildCallAction(Icons.call_end_rounded, Colors.red,
                    isEnd: true, onTap: () => Navigator.pop(context)),
                _buildCallAction(Icons.videocam_off_rounded, Colors.white24),
              ],
            ),
          ),
          // Match Info
          Positioned(
            top: 60,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const Text('Juice Call',
                    style: TextStyle(color: JuiceTheme.secondaryCitrus)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallAction(IconData icon, Color color,
      {bool isEnd = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isEnd ? 72 : 56,
        height: isEnd ? 72 : 56,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: isEnd ? 32 : 24),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video Placeholder
          Center(
            child: Icon(Icons.person, size: 200, color: Colors.white.withValues(alpha: 0.1)),
          ),
          // Local Video Preview
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.videocam_rounded, color: Colors.white24),
            ),
          ),
          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallAction(Icons.mic_none_rounded, Colors.white24),
                _buildCallAction(Icons.call_end_rounded, Colors.red,
                    isEnd: true, onTap: () => Navigator.pop(context)),
                _buildCallAction(Icons.videocam_off_rounded, Colors.white24),
              ],
            ),
          ),
          // Match Info
          const Positioned(
            top: 60,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sarah', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Juice Call (Tier 4)', style: TextStyle(color: JuiceTheme.secondaryCitrus)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallAction(IconData icon, Color color, {bool isEnd = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isEnd ? 72 : 56,
        height: isEnd ? 72 : 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: isEnd ? 32 : 24),
      ),
    );
  }
}
