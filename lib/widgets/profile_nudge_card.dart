import 'package:flutter/material.dart';
import '../core/theme/juice_theme.dart';
import '../models/user_models.dart';

class ProfileNudgeCard extends StatelessWidget {
  final JuiceUser user;
  final int score;
  final List<String> missing;
  final VoidCallback onComplete;

  const ProfileNudgeCard({
    super.key,
    required this.user,
    required this.score,
    required this.missing,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              JuiceTheme.primaryTangerine.withValues(alpha: 0.9),
              JuiceTheme.secondaryCitrus.withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Background decoration
            Positioned(
              right: -30,
              top: -30,
              child: Icon(
                Icons.person_add_rounded,
                size: 200,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "🍊",
                    style: TextStyle(fontSize: 64),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Boost Your Juice!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Complete your profile to get up to 5x more matches. People love to see who you really are!",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Progress indicator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Profile Strength",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "$score%",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: score / 100,
                          minHeight: 10,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Missing items
                  if (missing.isNotEmpty)
                    Column(
                      children: missing.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              item,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  
                  const Spacer(),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: JuiceTheme.primaryTangerine,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      onPressed: onComplete,
                      child: const Text(
                        "COMPLETE PROFILE",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {}, // Just for UI
                    child: const Text(
                      "SWIPE TO SKIP",
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
