import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/database_service.dart';
import 'symmetry_rank_system.dart';
import 'symmetry_workout_ledger.dart';
import 'macro_bridge.dart';
import 'muscle_fatigue_map.dart';

class SymmetryProgressionService {
  static final SymmetryProgressionService _instance =
      SymmetryProgressionService._internal();
  factory SymmetryProgressionService() => _instance;
  SymmetryProgressionService._internal();

  static const String _storageKey = 'symmetry_progression';
  static const double _baseXPPerTonnage = 1.0;
  static const double _streakBonusXP = 0.1;

  /// Las sesiones externas aportan progreso, pero a mitad de la tasa de una
  /// sesión registrada en CalAI. Health Connect no suele proporcionar
  /// tonelaje, series ni repeticiones fiables para aplicar la fórmula nativa.
  static const double importedWorkoutXpMultiplier = 0.5;
  static const double _importedXpPerActiveMinute = 1.0;
  static const double _importedXpPerCalorie = 0.1;
  static const double _consistencyBonusXP = 0.05;

  final SymmetryWorkoutLedger _ledger = SymmetryWorkoutLedger();
  final MacroBridge _macroBridge = MacroBridge();
  final MuscleFatigueMap _fatigueMap = MuscleFatigueMap();

  double _totalXP = 0;
  double _dailyXP = 0;
  double _weeklyXP = 0;
  int _streakDays = 0;
  DateTime? _lastWorkoutDate;
  DateTime? _lastDailyReset;
  DateTime? _lastWeeklyReset;
  bool _isInitialized = false;

  double get totalXP => _totalXP;
  double get dailyXP => _dailyXP;
  double get weeklyXP => _weeklyXP;
  int get streakDays => _streakDays;
  bool get isInitialized => _isInitialized;

  static const String _migratedWorkoutsKey = 'migrated_workouts_v1';

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _ledger.loadFromStorage();
    await _macroBridge.initialize();
    await _loadFromStorage();
    await _migrateWorkoutSessions();
    ensureFreshPeriods();
    _isInitialized = true;
  }

  /// Migración one-shot: el historial de sesiones vivía solo en el JSON de
  /// SymmetryWorkoutLedger (máx. 30 sesiones, sin índice). Se copia a
  /// workout_sessions para que sea consultable y permita rachas cruzadas
  /// (comida + entrenamiento).
  Future<void> _migrateWorkoutSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migratedWorkoutsKey) ?? false) return;

      final db = DatabaseService();
      final existing = await db.countWorkoutSessions();
      if (existing > 0) {
        await prefs.setBool(_migratedWorkoutsKey, true);
        return;
      }
      if (_ledger.recentWorkouts.isEmpty) {
        await prefs.setBool(_migratedWorkoutsKey, true);
        return;
      }

      for (final session in _ledger.recentWorkouts) {
        await db.insertWorkoutSession(
          date: session.date,
          totalTonnage: session.totalTonnage,
          durationMinutes: session.durationMinutes,
          muscleGroupTonnage: session.muscleGroupTonnage,
          // Historial legado: el XP exacto de entonces no se conservó.
          xpEarned: 0.0,
        );
      }
      await prefs.setBool(_migratedWorkoutsKey, true);
      debugPrint(
          'Symmetry: ${_ledger.recentWorkouts.length} sesiones migradas a SQLite');
    } catch (e) {
      // La migración no debe romper el arranque; se reintenta la próxima vez.
      debugPrint('Symmetry: error migrando sesiones a SQLite: $e');
    }
  }

  /// Reinicia el XP diario/semanal cuando cambia el día/semana.
  /// Antes estos contadores crecían infinito porque nadie los reseteaba.
  void ensureFreshPeriods() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool dirty = false;

    if (_lastDailyReset == null ||
        today.difference(_lastDailyReset!).inDays >= 1) {
      if (_dailyXP != 0) _dailyXP = 0;
      _lastDailyReset = today;
      dirty = true;
    }

    // Semana que empieza el lunes
    final weekStart =
        today.subtract(Duration(days: today.weekday - 1));
    if (_lastWeeklyReset == null || _lastWeeklyReset!.isBefore(weekStart)) {
      if (_weeklyXP != 0) _weeklyXP = 0;
      _lastWeeklyReset = weekStart;
      dirty = true;
    }

    if (dirty) _saveToStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        _totalXP = (data['totalXP'] as num?)?.toDouble() ?? 0;
        _dailyXP = (data['dailyXP'] as num?)?.toDouble() ?? 0;
        _weeklyXP = (data['weeklyXP'] as num?)?.toDouble() ?? 0;
        _streakDays = (data['streakDays'] as num?)?.toInt() ?? 0;
        if (data['lastWorkoutDate'] != null) {
          _lastWorkoutDate = DateTime.parse(data['lastWorkoutDate'] as String);
        }
        _lastDailyReset =
            DateTime.tryParse(data['lastDailyReset'] as String? ?? '');
        _lastWeeklyReset =
            DateTime.tryParse(data['lastWeeklyReset'] as String? ?? '');
      }
    } catch (e) {
      // Start fresh
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'totalXP': _totalXP,
        'dailyXP': _dailyXP,
        'weeklyXP': _weeklyXP,
        'streakDays': _streakDays,
        'lastWorkoutDate': _lastWorkoutDate?.toIso8601String(),
        'lastDailyReset': _lastDailyReset?.toIso8601String(),
        'lastWeeklyReset': _lastWeeklyReset?.toIso8601String(),
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      // Ignore
    }
  }

  Future<double> addWorkout({
    required double tonnage,
    required int durationMinutes,
    required String muscleGroup,
    required List<ExerciseRecord> exercises,
  }) async {
    ensureFreshPeriods();

    final session = WorkoutSession(
      date: DateTime.now(),
      totalTonnage: tonnage,
      durationMinutes: durationMinutes,
      muscleGroupTonnage: {muscleGroup: tonnage},
      exercises: exercises,
    );

    _ledger.addWorkout(session);
    _fatigueMap.updateFromWorkout(session);

    _updateStreak();

    final earnedXP = _calculateXPGain(tonnage);
    final multiplier = _macroBridge.proteinMultiplier;
    final effectiveXP = earnedXP * multiplier;

    // Historial consultable en SQLite (workout_sessions). El JSON del bridge
    // sigue guardando los contadores, pero la sesión persiste de forma
    // indexada por fecha.
    try {
      await DatabaseService().insertWorkoutSession(
        date: session.date,
        totalTonnage: tonnage,
        durationMinutes: durationMinutes,
        muscleGroupTonnage: session.muscleGroupTonnage,
        xpEarned: effectiveXP,
      );
    } catch (e) {
      // Si la persistencia de la sesión falla, el XP no se pierde (los
      // contadores se guardan justo debajo); solo falta la fila en SQLite.
      debugPrint('Symmetry: no se pudo persistir la sesión en SQLite: $e');
    }

    _totalXP += effectiveXP;
    _dailyXP += effectiveXP;
    _weeklyXP += effectiveXP;
    _lastWorkoutDate = DateTime.now();

    await _saveToStorage();

    return effectiveXP;
  }

  /// Estima el XP base de una sesión importada sin inventar tonelaje.
  /// Health Connect suele exponer duración y/o calorías, que son las únicas
  /// señales cuantitativas disponibles de forma consistente.
  static double calculateImportedWorkoutXp(WorkoutSession session) {
    final byDuration =
        session.durationMinutes * _importedXpPerActiveMinute;
    final byCalories = session.caloriesBurned * _importedXpPerCalorie;
    final base = byCalories > byDuration ? byCalories : byDuration;
    return base * importedWorkoutXpMultiplier;
  }

  /// Registra la progresión de una sesión externa ya deduplicada por
  /// Health Connect. No inserta otra fila SQLite: esa responsabilidad sigue
  /// siendo de GoogleFitService.
  Future<double> addImportedWorkout(WorkoutSession session) async {
    ensureFreshPeriods();
    final xp = calculateImportedWorkoutXp(session) *
        _macroBridge.proteinMultiplier;

    _ledger.addWorkout(session);
    _fatigueMap.updateFromWorkout(session);
    _totalXP += xp;

    // No trasladamos todo el histórico importado al contador diario/semanal.
    // Solo una sesión de hoy afecta esos contadores.
    final now = DateTime.now();
    final sessionDay =
        DateTime(session.date.year, session.date.month, session.date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (sessionDay == today) {
      _dailyXP += xp;
    }
    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
    if (!sessionDay.isBefore(currentWeekStart)) {
      _weeklyXP += xp;
    }

    await _saveToStorage();
    return xp;
  }

  double _calculateXPGain(double tonnage) {
    double xp = tonnage * _baseXPPerTonnage;

    if (_streakDays > 1) {
      xp *= (1 + (_streakDays * _streakBonusXP).clamp(0, 0.5));
    }

    if (_ledger.totalWorkouts > 10) {
      xp *= (1 + _consistencyBonusXP);
    }

    return xp;
  }

  void _updateStreak() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastWorkoutDate != null) {
      final lastDay = DateTime(
        _lastWorkoutDate!.year,
        _lastWorkoutDate!.month,
        _lastWorkoutDate!.day,
      );

      final difference = today.difference(lastDay).inDays;

      if (difference == 1) {
        _streakDays++;
      } else if (difference > 1) {
        _streakDays = 1;
      }
    } else {
      _streakDays = 1;
    }
  }

  void resetDailyXP() {
    _dailyXP = 0;
  }

  void resetWeeklyXP() {
    _weeklyXP = 0;
  }

  /// Racha de disciplina: días CONSECUTIVOS con al menos 1 comida
  /// registrada (food_entries) Y al menos 1 entrenamiento completado
  /// (workout_sessions). Independiente de la racha solo-entrenamiento
  /// (streakDays), que es la que da el multiplicador de XP.
  ///
  /// Se cuenta hacia atrás desde hoy; si hoy aún no cumple (normal a
  /// media jornada), la racha se evalúa desde ayer hacia atrás.
  Future<int> getDisciplineStreak() async {
    final db = DatabaseService();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 3650));
    try {
      // La implementación anterior hacía hasta 7.300 consultas SQLite
      // secuenciales (dos por cada día). En móviles eso bloqueaba el dashboard
      // y daba la sensación de que la app se había quedado colgada.
      final days = await Future.wait([
        db.getFoodDateKeysBetween(start, today),
        db.getWorkoutDateKeysBetween(start, today),
      ]);
      final foodDays = days[0];
      final workoutDays = days[1];
      var date = DateTime(today.year, today.month, today.day);
      if (!_containsDay(foodDays, workoutDays, date)) {
        date = date.subtract(const Duration(days: 1));
      }
      var streak = 0;
      for (var i = 0; i < 3650; i++) {
        if (!_containsDay(foodDays, workoutDays, date)) break;
        streak++;
        date = date.subtract(const Duration(days: 1));
      }
      return streak;
    } catch (e) {
      debugPrint('Symmetry: error consultando racha de disciplina: $e');
      return 0;
    }
  }

  bool _containsDay(Set<String> foodDays, Set<String> workoutDays,
      DateTime date) {
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return foodDays.contains(key) && workoutDays.contains(key);
  }

  SymmetryProgress getProgress() {
    ensureFreshPeriods();
    final currentRank = SymmetryRank.fromXP(_totalXP);
    final nextRank = currentRank.nextRank;

    double rankProgress = 0;
    if (nextRank != null) {
      final xpInCurrentRank = _totalXP - currentRank.minXP;
      final xpNeeded = nextRank.minXP - currentRank.minXP;
      rankProgress = (xpInCurrentRank / xpNeeded).clamp(0, 1);
    } else {
      rankProgress = 1;
    }

    return SymmetryProgress(
      totalXP: _totalXP,
      currentRank: currentRank,
      rankProgress: rankProgress,
      dailyXP: _dailyXP,
      weeklyXP: _weeklyXP,
      streakDays: _streakDays.toDouble(),
      proteinMultiplier: _macroBridge.proteinMultiplier,
      metProteinGoal: _macroBridge.metProteinGoal,
    );
  }

  Map<String, dynamic> getFullStats() {
    return {
      'progress': getProgress(),
      'workoutLedger': {
        'totalTonnage': _ledger.totalTonnage,
        'totalWorkouts': _ledger.totalWorkouts,
        'totalDurationMinutes': _ledger.totalDurationMinutes,
        'mostTrainedMuscles': _ledger.getMostTrainedMuscles(),
        'leastTrainedMuscles': _ledger.getLeastTrainedMuscles(),
      },
      'fatigueMap': _fatigueMap.getDetailedAnalysis(),
      'macroBridge': {
        'dailyProtein': _macroBridge.dailyProtein,
        'proteinGoal': _macroBridge.proteinGoal,
        'metGoal': _macroBridge.metProteinGoal,
        'multiplier': _macroBridge.proteinMultiplier,
        'statusMessage': _macroBridge.getProteinStatusMessage(),
      },
    };
  }

  List<Map<String, dynamic>> getRankHierarchy() {
    return SymmetryRank.getRankHierarchy();
  }

  Future<void> setProteinGoal(double grams) async {
    await _macroBridge.setProteinGoal(grams);
  }

  Map<String, double> getMuscleHeatMap() {
    return _fatigueMap.getHeatMap();
  }

  List<String> getWorkoutRecommendations() {
    final recommended = _fatigueMap.getRecommendedMuscles();
    final fatigued = _fatigueMap.getFatiguedMuscles();

    if (recommended.isEmpty && _ledger.totalWorkouts == 0) {
      return ['Comienza con un entrenamiento completo'];
    }

    return [
      if (recommended.isNotEmpty)
        'Músculos recuperados para entrenar hoy: ${recommended.join(", ")}',
      if (fatigued.isNotEmpty)
        'Músculos en recuperación: ${fatigued.join(", ")}',
      if (_fatigueMap.getOverallSymmetryScore() < 70)
        'Mejora tu simetría trabajando: ${_fatigueMap.getImbalancedMuscles().join(", ")}',
    ];
  }

  void reset() {
    _totalXP = 0;
    _dailyXP = 0;
    _weeklyXP = 0;
    _streakDays = 0;
    _lastWorkoutDate = null;
    _lastDailyReset = null;
    _lastWeeklyReset = null;
    _ledger.reset();
    _fatigueMap.reset();
    _saveToStorage();
  }
}
