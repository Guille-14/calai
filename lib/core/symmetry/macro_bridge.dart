import 'package:shared_preferences/shared_preferences.dart';

import '../utils/date_key.dart';

class MacroBridge {
  static final MacroBridge _instance = MacroBridge._internal();
  factory MacroBridge() => _instance;
  MacroBridge._internal();

  static const String _proteinGoalKey = 'symmetry_protein_goal';
  static const String _dailyProteinKey = 'daily_protein_';

  double _dailyProtein = 0;
  double _proteinGoal = 120;
  DateTime? _lastProteinUpdate;

  double get dailyProtein => _dailyProtein;
  double get proteinGoal => _proteinGoal;
  bool get metProteinGoal => _dailyProtein >= _proteinGoal;

  double get proteinProgress => (_dailyProtein / _proteinGoal).clamp(0.0, 1.0);

  double get proteinMultiplier => metProteinGoal ? 1.2 : 1.0;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _proteinGoal = prefs.getDouble(_proteinGoalKey) ?? 120;

    final today = DateTime.now();
    final dateKey = _dailyProteinKey + formatDateKey(today);

    var storedProtein = prefs.getDouble(dateKey);
    if (storedProtein == null) {
      // Migración: antes las claves se generaban SIN ceros a la izquierda
      // (p. ej. 'daily_protein_2026-9-6'). Si hoy existe una clave legacy,
      // se mueve al formato canónico para no perder el valor del día.
      final legacyKey =
          '${_dailyProteinKey}${today.year}-${today.month}-${today.day}';
      final legacyProtein = prefs.getDouble(legacyKey);
      if (legacyProtein != null) {
        storedProtein = legacyProtein;
        await prefs.setDouble(dateKey, legacyProtein);
        await prefs.remove(legacyKey);
        final legacyTime = prefs.getString('${legacyKey}_time');
        if (legacyTime != null) {
          await prefs.setString('${dateKey}_time', legacyTime);
          await prefs.remove('${legacyKey}_time');
        }
      }
    }
    _dailyProtein = storedProtein ?? 0;
    _lastProteinUpdate = prefs.getString('${dateKey}_time') != null
        ? DateTime.tryParse(prefs.getString('${dateKey}_time')!)
        : null;
  }

  Future<void> setProteinGoal(double goal) async {
    _proteinGoal = goal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_proteinGoalKey, goal);
  }

  Future<void> addProtein(double grams) async {
    _dailyProtein += grams;
    _lastProteinUpdate = DateTime.now();

    final today = DateTime.now();
    final dateKey = _dailyProteinKey + formatDateKey(today);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(dateKey, _dailyProtein);
    await prefs.setString(
        '${dateKey}_time', _lastProteinUpdate!.toIso8601String());
  }

  Future<void> resetDailyProtein() async {
    _dailyProtein = 0;
    _lastProteinUpdate = null;
  }

  Future<void> syncFromFoodLog({
    required double totalProtein,
    required DateTime date,
  }) async {
    final today = DateTime.now();
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      final dateKey = _dailyProteinKey + formatDateKey(date);
      _dailyProtein = totalProtein;
      _lastProteinUpdate = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(dateKey, _dailyProtein);
      await prefs.setString(
          '${dateKey}_time', _lastProteinUpdate!.toIso8601String());
    }
  }

  Future<double> getTodayProtein() async {
    final today = DateTime.now();
    final dateKey = _dailyProteinKey + formatDateKey(today);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(dateKey) ?? 0;
  }

  Future<Map<String, dynamic>> getWeeklyProteinStats() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    double weeklyTotal = 0;
    int daysMet = 0;
    double maxDay = 0;
    double minDay = double.infinity;

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = _dailyProteinKey + formatDateKey(date);
      final protein = prefs.getDouble(dateKey) ?? 0;
      weeklyTotal += protein;
      if (protein >= _proteinGoal) daysMet++;
      if (protein > maxDay) maxDay = protein;
      if (protein > 0 && protein < minDay) minDay = protein;
    }

    return {
      'weeklyTotal': weeklyTotal,
      'daysMetGoal': daysMet,
      'averageDaily': weeklyTotal / 7,
      'maxDay': maxDay,
      'minDay': minDay == double.infinity ? 0 : minDay,
    };
  }

  String getProteinStatusMessage() {
    final remaining = _proteinGoal - _dailyProtein;
    if (remaining <= 0) {
      return '¡Meta de proteína cumplida! 🎉 Multiplicador x1.2 activo';
    } else if (remaining <= 20) {
      return '¡Casi llegas! Solo ${remaining.toInt()}g restantes';
    } else if (remaining <= 50) {
      return 'Buen progreso: ${remaining.toInt()}g restantes';
    } else {
      return 'Faltan ${remaining.toInt()}g para tu objetivo';
    }
  }
}
