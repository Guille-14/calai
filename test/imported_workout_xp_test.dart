import 'package:flutter_test/flutter_test.dart';

import 'package:calorie_lens/core/symmetry/symmetry_progression_service.dart';
import 'package:calorie_lens/core/symmetry/symmetry_workout_ledger.dart';

void main() {
  group('XP de entrenamientos importados', () {
    test('aplica el 50 por ciento sobre la duración', () {
      const session = WorkoutSession(
        date: DateTime(2026, 9, 18),
        totalTonnage: 0,
        durationMinutes: 40,
        muscleGroupTonnage: {},
        exercises: [],
      );

      expect(
        SymmetryProgressionService.calculateImportedWorkoutXp(session),
        20,
      );
    });

    test('usa calorías cuando aportan una señal mayor que la duración', () {
      const session = WorkoutSession(
        date: DateTime(2026, 9, 18),
        totalTonnage: 0,
        durationMinutes: 20,
        muscleGroupTonnage: {},
        exercises: [],
        caloriesBurned: 400,
      );

      expect(
        SymmetryProgressionService.calculateImportedWorkoutXp(session),
        20,
      );
    });
  });
}
