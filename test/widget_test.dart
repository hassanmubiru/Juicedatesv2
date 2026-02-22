import 'package:flutter_test/flutter_test.dart';
import 'package:juicedates/core/utils/juice_engine.dart';

void main() {
  group('JuiceEngine', () {
    test('computeJuiceProfile returns correct averages per category', () {
      final answers = [
        QuizAnswer(category: 'family', score: 1.0),
        QuizAnswer(category: 'family', score: 0.0),
        QuizAnswer(category: 'career', score: 1.0),
        QuizAnswer(category: 'lifestyle', score: 0.5),
        QuizAnswer(category: 'ethics', score: 1.0),
        QuizAnswer(category: 'fun', score: 0.0),
      ];

      final profile = JuiceEngine.computeJuiceProfile(answers);

      expect(profile['family'], 0.5);
      expect(profile['career'], 1.0);
      expect(profile['lifestyle'], 0.5);
      expect(profile['ethics'], 1.0);
      expect(profile['fun'], 0.0);
    });

    test('computeJuiceProfile defaults missing categories to 0.5', () {
      final profile = JuiceEngine.computeJuiceProfile([]);
      for (final cat in JuiceEngine.categories) {
        expect(profile[cat], 0.5, reason: 'Default for $cat should be 0.5');
      }
    });

    test('sparksPotential returns 100 for identical profiles with voice', () {
      final p = JuiceProfile(family: 1, career: 1, lifestyle: 1, ethics: 1, fun: 1);
      final score = JuiceEngine.sparksPotential(p, p, hasVoice: true, momentum: 1.0);
      expect(score, 100.0);
    });

    test('sparksPotential is clamped between 0 and 100', () {
      final p = JuiceProfile(family: 0, career: 0, lifestyle: 0, ethics: 0, fun: 0);
      final q = JuiceProfile(family: 1, career: 1, lifestyle: 1, ethics: 1, fun: 1);
      final score = JuiceEngine.sparksPotential(p, q, hasVoice: false, momentum: 0);
      expect(score, greaterThanOrEqualTo(0.0));
      expect(score, lessThanOrEqualTo(100.0));
    });
  });

  group('JuiceProfile', () {
    test('toJson and fromJson round-trip', () {
      final profile = JuiceProfile(family: 0.9, career: 0.6, lifestyle: 0.8, ethics: 0.7, fun: 0.5);
      final json = profile.toJson();
      final restored = JuiceProfile.fromJson(json);

      expect(restored.family, profile.family);
      expect(restored.career, profile.career);
      expect(restored.lifestyle, profile.lifestyle);
      expect(restored.ethics, profile.ethics);
      expect(restored.fun, profile.fun);
    });
  });
}
