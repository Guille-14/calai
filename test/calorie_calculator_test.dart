import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_lens/core/utils/calorie_calculator.dart';

/// Casos calculados a mano con la fórmula Mifflin-St Jeor (1990):
///   Hombres: BMR = 10*kg + 6.25*cm - 5*edad + 5
///   Mujeres: BMR = 10*kg + 6.25*cm - 5*edad - 161
///   Otro:    promedio de ambas
/// TDEE = BMR * multiplicador de actividad.
void main() {
  group('Mifflin-St Jeor (BMR real)', () {
    test('Hombre 80kg 180cm 30a sedentario: BMR 1780, TDEE 2136', () {
      // BMR = 800 + 1125 - 150 + 5 = 1780
      // TDEE = 1780 * 1.2 = 2136
      expect(
        CalorieCalculator.fallbackEstimateCalories(
          weight: 80,
          height: 180,
          age: 30,
          activityLevel: 'Sedentary',
          gender: 'Male',
        ),
        2136,
      );
    });

    test('Mujer 65kg 165cm 25a sedentaria: BMR 1395.25, TDEE 1674', () {
      // BMR = 650 + 1031.25 - 125 - 161 = 1395.25
      // TDEE = 1395.25 * 1.2 = 1674.3 -> 1674 (toInt)
      expect(
        CalorieCalculator.fallbackEstimateCalories(
          weight: 65,
          height: 165,
          age: 25,
          activityLevel: 'Sedentary',
          gender: 'Female',
        ),
        1674,
      );
    });

    test('Mujer 65kg 165cm 25a moderada: 1395.25 * 1.55 = 2162', () {
      // TDEE = 1395.25 * 1.55 = 2162.6375 -> 2162
      expect(
        CalorieCalculator.fallbackEstimateCalories(
          weight: 65,
          height: 165,
          age: 25,
          activityLevel: 'Moderate',
          gender: 'Female',
        ),
        2162,
      );
    });

    test('Hombre 80kg 180cm 30a ligero: 1780 * 1.375 = 2447', () {
      // TDEE = 1780 * 1.375 = 2447.5 -> 2447 (toInt trunca)
      expect(
        CalorieCalculator.fallbackEstimateCalories(
          weight: 80,
          height: 180,
          age: 30,
          activityLevel: 'Light',
          gender: 'Male',
        ),
        2447,
      );
    });

    test('Hombre 80kg 180cm 30a muy activo: 1780 * 1.9 = 3382', () {
      expect(
        CalorieCalculator.fallbackEstimateCalories(
          weight: 80,
          height: 180,
          age: 30,
          activityLevel: 'Very Active',
          gender: 'Male',
        ),
        3382,
      );
    });

    test('Otro: promedio de ambas fórmulas (80/180/30 sedentario)', () {
      // BMR hombre = 1780, BMR mujer = 1614 -> promedio 1697
      // TDEE = 1697 * 1.2 = 2036.4 -> 2036
      expect(
        CalorieCalculator.fallbackEstimateCalories(
          weight: 80,
          height: 180,
          age: 30,
          activityLevel: 'Sedentary',
          gender: 'Other',
        ),
        2036,
      );
    });

    test('Actividad desconocida: cae a sedentario (x1.2)', () {
      expect(
        CalorieCalculator.fallbackEstimateCalories(
          weight: 80,
          height: 180,
          age: 30,
          activityLevel: 'NO EXISTE',
          gender: 'Male',
        ),
        2136,
      );
    });

    test('El sexo cambia el BMR en exactamente 166 kcal', () {
      // La diferencia entre las dos fórmulas es +5 vs -161 -> 166.
      final male = CalorieCalculator.fallbackEstimateCalories(
        weight: 70,
        height: 170,
        age: 35,
        activityLevel: 'Sedentary',
        gender: 'Male',
      );
      final female = CalorieCalculator.fallbackEstimateCalories(
        weight: 70,
        height: 170,
        age: 35,
        activityLevel: 'Sedentary',
        gender: 'Female',
      );
      // 166 * 1.2 = 199.2 -> la diferencia truncada está en [199, 200]
      expect(male - female, inInclusiveRange(199, 200));
    });
  });

  group('Ajuste por objetivo', () {
    test('Pérdida de peso: déficit del 20%', () {
      expect(
        CalorieCalculator.calculateCaloriesBasedOnGoal(
            maintenanceCalories: 2000, goal: 'Weight Loss'),
        1600,
      );
    });

    test('Ganancia de músculo: superávit del 15%', () {
      expect(
        CalorieCalculator.calculateCaloriesBasedOnGoal(
            maintenanceCalories: 2000, goal: 'Muscle Gain'),
        2300,
      );
    });

    test('Mantener: sin ajuste', () {
      expect(
        CalorieCalculator.calculateCaloriesBasedOnGoal(
            maintenanceCalories: 2000, goal: 'Maintain'),
        2000,
      );
    });
  });

  group('calculateMacroGoals (3 objetivos, valores a mano)', () {
    test('Mantener 2000 kcal: 25/25/50', () {
      // proteína 25% -> 500/4 = 125 g
      // grasa 25%    -> 500/9 = 55.56 -> 56 g
      // carbo 50%    -> 1000/4 = 250 g
      final macros = CalorieCalculator.calculateMacroGoals(
        calories: 2000,
        goal: 'Maintain',
      );
      expect(macros['proteinGoal'], 125);
      expect(macros['fatGoal'], 56);
      expect(macros['carbsGoal'], 250);
    });

    test('Pérdida 2000 kcal: 30/25/45', () {
      // proteína 30% -> 600/4 = 150 g
      // grasa 25%    -> 500/9 = 55.56 -> 56 g
      // carbo 45%    -> 900/4 = 225 g
      final macros = CalorieCalculator.calculateMacroGoals(
        calories: 2000,
        goal: 'Weight Loss',
      );
      expect(macros['proteinGoal'], 150);
      expect(macros['fatGoal'], 56);
      expect(macros['carbsGoal'], 225);
    });

    test('Ganancia 2500 kcal: 25/25/50', () {
      // proteína 25% -> 625/4 = 156.25 -> 156 g
      // grasa 25%    -> 625/9 = 69.44 -> 69 g
      // carbo 50%    -> 1250/4 = 312.5 -> 313 g (round)
      final macros = CalorieCalculator.calculateMacroGoals(
        calories: 2500,
        goal: 'Muscle Gain',
      );
      expect(macros['proteinGoal'], 156);
      expect(macros['fatGoal'], 69);
      expect(macros['carbsGoal'], 313);
    });
  });
}
