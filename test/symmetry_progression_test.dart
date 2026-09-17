import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calorie_lens/core/symmetry/symmetry_progression_service.dart';
import 'package:calorie_lens/core/symmetry/symmetry_rank_system.dart';
import 'package:calorie_lens/core/symmetry/macro_bridge.dart';

/// Constantes de XP (symmetry_progression_service.dart):
///   base = 1 XP por kg de tonelaje
///   bonus racha  = +10% por día de racha (máx. +50%), solo si racha > 1
///   consistencia = +5% con más de 10 entrenamientos acumulados
///   multiplicador de proteína (MacroBridge) = x1.2 si se cumplió la meta
void main() {
  group('Límites exactos de rango (fromXP)', () {
    test('499 XP = Hierro, 500 XP = Bronce', () {
      expect(SymmetryRank.fromXP(499), SymmetryRank.iron);
      expect(SymmetryRank.fromXP(499).displayName, 'Hierro');
      expect(SymmetryRank.fromXP(500), SymmetryRank.bronze);
      expect(SymmetryRank.fromXP(500).displayName, 'Bronce');
    });

    test('0 XP = Hierro', () {
      expect(SymmetryRank.fromXP(0), SymmetryRank.iron);
    });

    test('todos los límites de la jerarquía', () {
      expect(SymmetryRank.fromXP(1999.9), SymmetryRank.bronze);
      expect(SymmetryRank.fromXP(2000), SymmetryRank.silver);
      expect(SymmetryRank.fromXP(4999), SymmetryRank.gold);
      expect(SymmetryRank.fromXP(5000), SymmetryRank.platinum);
      expect(SymmetryRank.fromXP(11999), SymmetryRank.platinum);
      expect(SymmetryRank.fromXP(12000), SymmetryRank.emerald);
      expect(SymmetryRank.fromXP(29999), SymmetryRank.emerald);
      expect(SymmetryRank.fromXP(30000), SymmetryRank.diamond);
      expect(SymmetryRank.fromXP(69999), SymmetryRank.diamond);
      expect(SymmetryRank.fromXP(70000), SymmetryRank.master);
      expect(SymmetryRank.fromXP(149999), SymmetryRank.master);
      expect(SymmetryRank.fromXP(150000), SymmetryRank.champion);
      expect(SymmetryRank.fromXP(299999), SymmetryRank.champion);
      expect(SymmetryRank.fromXP(300000), SymmetryRank.symmetric);
      expect(SymmetryRank.fromXP(1000000), SymmetryRank.symmetric);
    });

    test('nextRank: cadena correcta y null solo en Simétrico', () {
      expect(SymmetryRank.iron.nextRank, SymmetryRank.bronze);
      expect(SymmetryRank.bronze.nextRank, SymmetryRank.silver);
      expect(SymmetryRank.champion.nextRank, SymmetryRank.symmetric);
      expect(SymmetryRank.symmetric.nextRank, isNull);
    });
  });

  group('XP de entrenamientos (racha y multiplicador de proteína)', () {
    final service = SymmetryProgressionService();
    final macroBridge = MacroBridge();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service.reset();
      await macroBridge.resetDailyProtein();
      await macroBridge.setProteinGoal(120);
    });

    // IMPORTANTE: este test va PRIMERO porque necesita initialize() del
    // servicio (que es singleton y no se re-ejecuta si ya está
    // inicializado) y MacroBridge sin proteína.
    test('racha de 2 días: bonus x1.2 sobre el XP base', () async {
      // Simula un entrenamiento de AYER guardado en el storage.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'symmetry_progression': jsonEncode({
          'totalXP': 0,
          'dailyXP': 0,
          'weeklyXP': 0,
          'streakDays': 1,
          'lastWorkoutDate': yesterday.toIso8601String(),
        }),
      });
      await service.initialize();
      expect(service.streakDays, 1);

      // Hoy entreno: racha pasa a 2 -> bonus (1 + 2*0.1) = x1.2.
      // Sin proteína cumplida: multiplicador x1.0.
      final xp = await service.addWorkout(
        tonnage: 500,
        durationMinutes: 45,
        muscleGroup: 'Pecho',
        exercises: [],
      );

      expect(service.streakDays, 2);
      expect(xp, closeTo(600, 1e-9)); // 500 * 1.0 * 1.2
    });

    test('primer entrenamiento: XP base, sin racha ni proteína (x1.0)',
        () async {
      final xp = await service.addWorkout(
        tonnage: 500,
        durationMinutes: 45,
        muscleGroup: 'Pecho',
        exercises: [],
      );
      expect(service.streakDays, 1); // sin bonus (requiere racha > 1)
      expect(xp, closeTo(500, 1e-9)); // 500 * 1.0
      expect(service.totalXP, closeTo(500, 1e-9));
      expect(service.dailyXP, closeTo(500, 1e-9));
    });

    test('proteína cumplida: el multiplicador x1.2 se aplica al XP',
        () async {
      await macroBridge.initialize();
      expect(macroBridge.proteinMultiplier, 1.0);

      await macroBridge.addProtein(120);
      expect(macroBridge.metProteinGoal, isTrue);
      expect(macroBridge.proteinMultiplier, 1.2);

      final xp = await service.addWorkout(
        tonnage: 500,
        durationMinutes: 45,
        muscleGroup: 'Pecho',
        exercises: [],
      );
      expect(xp, closeTo(600, 1e-9)); // 500 * 1.2
      expect(service.totalXP, closeTo(600, 1e-9));
    });

    test('sin proteína: misma tonelaje = mismo XP (x1.0)', () async {
      final xp1 = await service.addWorkout(
        tonnage: 500,
        durationMinutes: 45,
        muscleGroup: 'Espalda',
        exercises: [],
      );
      service.reset();
      final xp2 = await service.addWorkout(
        tonnage: 500,
        durationMinutes: 45,
        muscleGroup: 'Espalda',
        exercises: [],
      );
      expect(xp1, closeTo(500, 1e-9));
      expect(xp2, closeTo(xp1, 1e-9));
    });
  });
}
