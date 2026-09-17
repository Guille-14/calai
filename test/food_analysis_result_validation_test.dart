import 'package:flutter_test/flutter_test.dart';

import 'package:calorie_lens/data/models/food_analysis_result.dart';

void main() {
  group('FoodAnalysisResult validation', () {
    test('accepts the structured provider contract', () {
      final result = FoodAnalysisResult.fromJson({
        'name': 'Bowl de arroz',
        'calories': 540,
        'protein': 28,
        'carbs': 64,
        'fat': 18,
        'sugar': 4,
        'confidence': 'high',
      });

      expect(result.isError, isFalse);
      expect(result.foods, ['Bowl de arroz']);
      expect(result.estimatedCalories, 540);
      expect(result.confidence, 'high');
    });

    test('supports the legacy nested contract without weakening validation', () {
      final result = FoodAnalysisResult.fromJson({
        'foods': ['Avena'],
        'estimatedCalories': 320,
        'macros': {'protein': 12, 'carbs': 48, 'fat': 8},
        'confidence': 'medium',
      });

      expect(result.isError, isFalse);
      expect(result.totalMacroGrams, 68);
    });

    test('rejects incomplete or unsafe nutritional values', () {
      final result = FoodAnalysisResult.fromJson({
        'name': 'Plato imposible',
        'calories': -20,
        'protein': 4,
        'carbs': 3,
        'fat': 2,
      });

      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('calorías'));
    });
  });
}
