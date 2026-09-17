import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_lens/data/services/food_service.dart';

void main() {
  group('FoodAnalysisResult', () {
    test('acepta el payload legacy y normaliza macros', () {
      final result = FoodAnalysisResult.fromJson({
        'foods': ['Avena'],
        'estimatedCalories': 0,
        'macros': {'protein': 10, 'carbs': 20, 'fat': 5},
        'confidence': 'high',
      });

      expect(result.isError, isFalse);
      expect(result.foods, ['Avena']);
      expect(result.estimatedCalories, 165);
      expect(result.protein, 10);
      expect(result.confidence, 'high');
    });

    test('prefiere el esquema actual name/calories y no inventa alimentos', () {
      final result = FoodAnalysisResult.fromJson({
        'name': 'Ensalada',
        'calories': 320,
        'protein': 18.5,
        'carbs': 24,
        'fat': 14,
        'sugar': 3,
        'confidence': 'medium',
      });

      expect(result.isError, isFalse);
      expect(result.foods, ['Ensalada']);
      expect(result.estimatedCalories, 320);
      expect(result.totalMacroGrams, 56);
    });

    test('rechaza una respuesta sin comida ni datos nutricionales', () {
      final result = FoodAnalysisResult.fromJson(const {});

      expect(result.isError, isTrue);
      expect(result.errorMessage, isNotEmpty);
    });
  });
}
