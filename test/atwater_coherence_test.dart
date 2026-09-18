import 'package:flutter_test/flutter_test.dart';

import 'package:calorie_lens/data/models/food_analysis_result.dart';

void main() {
  group('Coherencia de calorías con los factores de Atwater', () {
    test('corrige el total cuando la IA se contradice con sus propios macros',
        () {
      // Caso real del informe: 30P/40C/10G suman 370 kcal, pero la IA
      // declaraba 550. Antes se mostraban las 550 y el usuario veía macros
      // que no cuadraban con las calorías.
      final result = FoodAnalysisResult.fromJson({
        'name': 'Plato incoherente',
        'calories': 550,
        'protein': 30,
        'carbs': 40,
        'fat': 10,
        'confidence': 'medium',
      });

      expect(result.isError, isFalse);
      expect(result.estimatedCalories, 370);
    });

    test('respeta el total de la IA si ya cuadra dentro del margen del 10%',
        () {
      // 28P/64C/18G = 530 kcal. La IA dice 540: desviación < 10%, así que no
      // se toca (los factores reales varían por fibra y redondeos).
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
      expect(result.estimatedCalories, 540);
    });

    test('deriva las calorías cuando la IA las omite', () {
      final result = FoodAnalysisResult.fromJson({
        'name': 'Tortilla',
        'calories': 0,
        'protein': 20,
        'carbs': 15,
        'fat': 12,
        'confidence': 'medium',
      });

      expect(result.isError, isFalse);
      // 20*4 + 15*4 + 12*9 = 248
      expect(result.estimatedCalories, 248);
    });

    test('el helper aplica 4/4/9 y 2 kcal por gramo de fibra', () {
      expect(
        FoodAnalysisResult.atwaterCalories(protein: 10, carbs: 10, fat: 10),
        170,
      );
      expect(
        FoodAnalysisResult.atwaterCalories(
            protein: 0, carbs: 0, fat: 0, fiber: 10),
        20,
      );
    });

    test('rechaza calorías negativas en vez de repararlas con los macros', () {
      // Un negativo indica respuesta corrupta, no una simple desviación: no
      // se debe "arreglar" recalculando, porque el resto de cifras del
      // proveedor tampoco son fiables.
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

    test('sigue rechazando un plato sin macros ni calorías', () {
      final result = FoodAnalysisResult.fromJson({
        'name': 'Vacío',
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
        'confidence': 'low',
      });

      expect(result.isError, isTrue);
    });
  });
}
