import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/juice_theme.dart';
import '../models/user_models.dart';

class JuiceCard extends StatelessWidget {
  final JuiceUser user;
  final double sparksScore;

  const JuiceCard({super.key, required this.user, this.sparksScore = 0});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photos.isNotEmpty
        ? user.photos.first
        : user.photoUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background photo or gradient placeholder
          photoUrl != null && photoUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => Container(
                    decoration: BoxDecoration(gradient: JuiceTheme.primaryGradient),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                  errorWidget: (ctx, url, err) => _buildGradientPlaceholder(),
                )
              : _buildGradientPlaceholder(),

          // Dark gradient overlay at bottom
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${user.displayName}, ${user.age}',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (sparksScore >= 75)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: JuiceTheme.juiceGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flash_on_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                '${sparksScore.round()}%',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white60, size: 14),
                      const SizedBox(width: 4),
                      Text(user.city, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user.juiceSummary,
                    style: const TextStyle(color: JuiceTheme.secondaryCitrus, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.bio!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                  if (user.interests.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: user.interests.take(4).map((interest) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Text(interest, style: const TextStyle(color: Colors.white, fontSize: 11)),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Photo count indicator dots at top
          if (user.photos.length > 1)
            Positioned(
              top: 12,
              left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(user.photos.length, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == 0 ? 20 : 6,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i == 0 ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGradientPlaceholder() {
    return Container(
      decoration: BoxDecoration(gradient: JuiceTheme.primaryGradient),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_rounded, size: 100, color: Colors.white54),
            const SizedBox(height: 8),
            Text(user.displayName[0].toUpperCase(),
              style: const TextStyle(fontSize: 60, color: Colors.white60, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.person,
                size: 100,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${user['name']}, ${user['age']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (user['sparks'] >= 80)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: JuiceTheme.juiceGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.flash_on_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${user['sparks']}% Sparks',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user['city'],
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user['summary'],
                    style: const TextStyle(color: JuiceTheme.secondaryCitrus, fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
