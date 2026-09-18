import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_lens/data/services/food_service.dart';

/// Regresión del fallo visto en un móvil real: Gemini devolvió el JSON
/// cortado a media clave ("...,\"protein\":") porque los "thinking tokens" se
/// comieron el presupuesto de maxOutputTokens. Ese truncado llegaba como
/// éxito y reventaba después en el parser.
void main() {
  group('Respuesta truncada de la IA', () {
    test('un truncado que solo deja nombre y calorías no pasa como válido',
        () {
      // Lo que sobrevive de '{"name":...,"calories":633,"protein":' si se
      // intentara rescatar: calorías sin ningún macro que las respalde.
      final result = FoodAnalysisResult.fromJson({
        'name': 'Ensalada de pasta con huevo, atún y mayonesa',
        'calories': 633,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
      });

      // 633 kcal con todos los macros a cero es imposible. La regla de
      // Atwater debe corregirlo o marcarlo como error, pero nunca guardar
      // 633 kcal junto a macros en blanco como si fueran datos medidos.
      if (!result.isError) {
        final macroDerived =
            result.protein * 4 + result.carbs * 4 + result.fat * 9;
        expect(
          result.estimatedCalories.toDouble(),
          closeTo(macroDerived, macroDerived * 0.10 + 1),
          reason: 'Las calorías deben cuadrar con los macros devueltos',
        );
      }
    });

    test('un plato completo sí se acepta con sus macros', () {
      // Control: la misma comida con la respuesta entera debe pasar, para
      // asegurar que la comprobación anterior no rechaza lo bueno.
      final result = FoodAnalysisResult.fromJson({
        'name': 'Ensalada de pasta con huevo, atún y mayonesa',
        'calories': 633,
        'protein': 25,
        'carbs': 55,
        'fat': 33,
      });

      expect(result.isError, isFalse);
      expect(result.foods, ['Ensalada de pasta con huevo, atún y mayonesa']);
      expect(result.protein, 25);
    });
  });
}
