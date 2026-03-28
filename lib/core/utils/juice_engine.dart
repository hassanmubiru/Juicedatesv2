class JuiceProfile {
  final double family;
  final double career;
  final double lifestyle;
  final double ethics;
  final double fun;

  JuiceProfile({
    required this.family,
    required this.career,
    required this.lifestyle,
    required this.ethics,
    required this.fun,
  });

  Map<String, dynamic> toJson() => {
        'family': family,
        'career': career,
        'lifestyle': lifestyle,
        'ethics': ethics,
        'fun': fun,
      };

  factory JuiceProfile.fromJson(Map<String, dynamic> json) => JuiceProfile(
        family: (json['family'] as num?)?.toDouble() ?? 0.5,
        career: (json['career'] as num?)?.toDouble() ?? 0.5,
        lifestyle: (json['lifestyle'] as num?)?.toDouble() ?? 0.5,
        ethics: (json['ethics'] as num?)?.toDouble() ?? 0.5,
        fun: (json['fun'] as num?)?.toDouble() ?? 0.5,
      );
}

class QuizAnswer {
  final String category;
  final double score;

  QuizAnswer({required this.category, required this.score});
}

class JuiceEngine {
  static const categories = ['family', 'career', 'lifestyle', 'ethics', 'fun'];

  static Map<String, double> computeJuiceProfile(List<QuizAnswer> answers) {
    Map<String, List<double>> grouped = {};
    for (var cat in categories) {
      grouped[cat] = [];
    }

    for (var ans in answers) {
      if (grouped.containsKey(ans.category)) {
        grouped[ans.category]!.add(ans.score);
      }
    }

    Map<String, double> profile = {};
    grouped.forEach((key, values) {
      if (values.isEmpty) {
        profile[key] = 0.5; // Default neutral
      } else {
        profile[key] = values.reduce((a, b) => a + b) / values.length;
      }
    });

    return profile;
  }

  /// Simple symmetric similarity score used when creating a mutual match.
  static double computeSparks(JuiceProfile a, JuiceProfile b) {
    final diff = (a.family - b.family).abs() +
        (a.career - b.career).abs() +
        (a.lifestyle - b.lifestyle).abs() +
        (a.ethics - b.ethics).abs() +
        (a.fun - b.fun).abs();
    return ((1 - diff / 5) * 100).clamp(0.0, 100.0);
  }

  static double sparksPotential(JuiceProfile a, JuiceProfile b, {bool hasVoice = false, double momentum = 0.5}) {
    // 85pt algorithm: 40% values (5 categories) + 20% voice + 15% momentum + 10% lifestyle

    // Values similarity across all 5 categories (family, career, ethics, fun, lifestyle)
    double valuesDiff = 0;
    valuesDiff += (a.family - b.family).abs();
    valuesDiff += (a.career - b.career).abs();
    valuesDiff += (a.ethics - b.ethics).abs();
    valuesDiff += (a.fun - b.fun).abs();
    double valuesScore = (1.0 - (valuesDiff / 4.0)) * 40;

    // Lifestyle similarity (separate weight)
    double lifestyleScore = (1.0 - (a.lifestyle - b.lifestyle).abs()) * 10;

    // Voice booster
    double voiceBonus = hasVoice ? 20 : 0;

    // Momentum (activity/replies)
    double momentumScore = momentum * 15;

    double totalScore = valuesScore + lifestyleScore + voiceBonus + momentumScore;

    // Clamp and scale to percentage (max possible = 85 points → 100%)
    return (totalScore / 85 * 100).clamp(0.0, 100.0);
  }

  /// Generates 3 conversation-starter questions tailored to the two users'
  /// strongest shared values from their JuiceProfiles.
  static List<String> generateIcebreakers(JuiceProfile a, JuiceProfile b) {
    final avgScores = {
      'family': (a.family + b.family) / 2,
      'career': (a.career + b.career) / 2,
      'lifestyle': (a.lifestyle + b.lifestyle) / 2,
      'ethics': (a.ethics + b.ethics) / 2,
      'fun': (a.fun + b.fun) / 2,
    };
    final sorted = avgScores.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));

    const questionMap = <String, List<String>>{
      'family': [
        'What does your ideal family Sunday look like?',
        'Do you see yourself wanting kids someday?',
        'Who in your family has influenced you the most?',
      ],
      'career': [
        "If money weren't a factor, what would you do for work?",
        'What drives you most in your professional life?',
        "What's the biggest risk you've taken in your career?",
      ],
      'lifestyle': [
        "Morning person or night owl — what's your perfect weekend look like?",
        "What's a non-negotiable part of your daily routine?",
        'Where in the world would you love to live and why?',
      ],
      'ethics': [
        'What personal value would you never compromise on?',
        'Is there a cause you care deeply about?',
        'What do you think most people get wrong about the world?',
      ],
      'fun': [
        "What's the most spontaneous thing you've ever done?",
        "What skill would you love to master overnight?",
        "What's your all-time favourite way to spend a free evening?",
      ],
    };

    final results = <String>[];
    for (final entry in sorted) {
      final qs = questionMap[entry.key];
      if (qs != null && qs.isNotEmpty) {
        results.add(qs[results.length % qs.length]);
      }
      if (results.length == 3) break;
    }
    return results;
  }

  /// Returns a 0–100 profile strength score and a list of missing field hints.
  static ({int score, List<String> missing}) computeProfileStrength(dynamic u) {
    // We use dynamic here to avoid circular dependencies with JuiceUser if needed,
    // though usually JuiceUser is available.
    final photos = u.photos as List<String>;
    final bio = u.bio as String?;
    final interests = u.interests as List<String>;
    final university = u.university as String?;
    final jobTitle = u.jobTitle as String?;
    final orientation = u.sexualOrientation as String?;
    final juiceProfile = u.juiceProfile;
    final city = u.city as String;

    final checks = <(bool, String)>[
      (photos.isNotEmpty, 'Add a profile photo'),
      (photos.length >= 3, 'Add 3+ photos'),
      (bio != null && bio.trim().length > 20, 'Write a longer bio'),
      (interests.length >= 3, 'Add 3+ interests'),
      (university != null && university.isNotEmpty, 'Add your university'),
      (jobTitle != null && jobTitle.isNotEmpty, 'Add your job title'),
      (orientation != null, 'Set sexual orientation'),
      (bio != null && bio.trim().isNotEmpty, 'Write something in your bio'),
      (juiceProfile.family > 0, 'Complete the Juice Quiz'),
      (city != 'Unknown' && city.isNotEmpty, 'Set your city'),
    ];
    final total = checks.length;
    final done = checks.where((c) => c.$1).length;
    final missing = checks
        .where((c) => !c.$1)
        .map((c) => c.$2)
        .toList();
    return (score: (done * 100 ~/ total), missing: missing.take(3).toList());
  }

  /// Returns the category name where both users have the highest shared average score.
  /// Result is a string like "Family Oriented" or "Career Focused".
  static String getStrongestSharedValue(JuiceProfile a, JuiceProfile b) {
    final avgScores = {
      'Family': (a.family + b.family) / 2,
      'Career': (a.career + b.career) / 2,
      'Lifestyle': (a.lifestyle + b.lifestyle) / 2,
      'Ethics': (a.ethics + b.ethics) / 2,
      'Fun': (a.fun + b.fun) / 2,
    };
    final sorted = avgScores.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    
    final best = sorted.first.key;
    switch (best) {
      case 'Family': return 'Family Oriented';
      case 'Career': return 'Career Focused';
      case 'Lifestyle': return 'Lifestyle Match';
      case 'Ethics': return 'Shared Ethics';
      case 'Fun': return 'Adventurous Spirits';
      default: return 'Shared Values';
    }
  }
}
