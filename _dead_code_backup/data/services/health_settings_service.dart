import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/health_context.dart';
import '../../core/ai/fitness_memory_service.dart';
import '../../core/ai/fitness_memory_profile.dart';

class HealthSettingsService extends ChangeNotifier {
  static HealthSettingsService? _instance;

  HealthSettingsService._internal();

  factory HealthSettingsService() {
    _instance ??= HealthSettingsService._internal();
    return _instance!;
  }

  static HealthSettingsService get instance => HealthSettingsService();

  bool _isMetricSystem = true;
  bool get isMetricSystem => _isMetricSystem;

  int _dailyCalories = 0;
  int get dailyCalories => _dailyCalories;
  
  double _dailyProtein = 0;
  double get dailyProtein => _dailyProtein;
  
  double _dailyCarbs = 0;
  double get dailyCarbs => _dailyCarbs;
  
  double _dailyFat = 0;
  double get dailyFat => _dailyFat;

  Future<void> addFoodEntry(int calories, double protein, double carbs, double fat) async {
    final prefs = await SharedPreferences.getInstance();
    _dailyCalories += calories;
    _dailyProtein += protein;
    _dailyCarbs += carbs;
    _dailyFat += fat;
    
    await prefs.setInt('daily_cals', _dailyCalories);
    await prefs.setDouble('daily_prot', _dailyProtein);
    await prefs.setDouble('daily_carb', _dailyCarbs);
    await prefs.setDouble('daily_fat', _dailyFat);
    notifyListeners();
  }


  
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isMetricSystem = prefs.getBool('isMetricSystem') ?? true;
    _dailyCalories = prefs.getInt('daily_cals') ?? 0;
    _dailyProtein = prefs.getDouble('daily_prot') ?? 0.0;
    _dailyCarbs = prefs.getDouble('daily_carb') ?? 0.0;
    _dailyFat = prefs.getDouble('daily_fat') ?? 0.0;
    notifyListeners();
  }


  Future<void> setMetricSystem(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _isMetricSystem = value;
    await prefs.setBool('isMetricSystem', value);
    notifyListeners();
  }

  Future<HealthContext> fetchTodayHealthContext() async {
    final memoryService =
        FitnessMemoryService(await SharedPreferences.getInstance());
    final profile = await memoryService.getProfile();

    final today = profile.recentDays.firstWhere(
      (d) =>
          d.date.year == DateTime.now().year &&
          d.date.month == DateTime.now().month &&
          d.date.day == DateTime.now().day,
      orElse: () => DailyFitnessRecord(date: DateTime.now()),
    );

    return HealthContext(
      stepsToday: today.steps,
      activeCaloriesToday: today.caloriesBurned.toDouble(),
      lastSyncTimestamp: DateTime.now(),
    );
  }
}
