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
        family: (json['family'] as num).toDouble(),
        career: (json['career'] as num).toDouble(),
        lifestyle: (json['lifestyle'] as num).toDouble(),
        ethics: (json['ethics'] as num).toDouble(),
        fun: (json['fun'] as num).toDouble(),
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
}
