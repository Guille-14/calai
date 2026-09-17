import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'symmetry_rank_system.dart';
import 'health_connect_bridge.dart';
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
  static const double _consistencyBonusXP = 0.05;

  final HealthConnectBridge _healthBridge = HealthConnectBridge();
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

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _healthBridge.loadFromStorage();
    await _macroBridge.initialize();
    await _loadFromStorage();
    ensureFreshPeriods();
    _isInitialized = true;
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

    _healthBridge.addWorkout(session);
    _fatigueMap.updateFromWorkout(session);

    _updateStreak();

    final earnedXP = _calculateXPGain(tonnage);
    final multiplier = _macroBridge.proteinMultiplier;
    final effectiveXP = earnedXP * multiplier;

    _totalXP += effectiveXP;
    _dailyXP += effectiveXP;
    _weeklyXP += effectiveXP;
    _lastWorkoutDate = DateTime.now();

    await _saveToStorage();

    return effectiveXP;
  }

  double _calculateXPGain(double tonnage) {
    double xp = tonnage * _baseXPPerTonnage;

    if (_streakDays > 1) {
      xp *= (1 + (_streakDays * _streakBonusXP).clamp(0, 0.5));
    }

    if (_healthBridge.totalWorkouts > 10) {
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
      'healthBridge': {
        'totalTonnage': _healthBridge.totalTonnage,
        'totalWorkouts': _healthBridge.totalWorkouts,
        'totalDurationMinutes': _healthBridge.totalDurationMinutes,
        'mostTrainedMuscles': _healthBridge.getMostTrainedMuscles(),
        'leastTrainedMuscles': _healthBridge.getLeastTrainedMuscles(),
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

    if (recommended.isEmpty && _healthBridge.totalWorkouts == 0) {
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
    _healthBridge.reset();
    _fatigueMap.reset();
    _saveToStorage();
  }
}
