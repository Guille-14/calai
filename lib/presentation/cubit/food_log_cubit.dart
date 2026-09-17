import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/symmetry/macro_bridge.dart';
import '../../core/utils/date_key.dart';
import '../../data/models/food_item.dart';
import '../../data/repositories/food_repository.dart';

class FoodLogState {
  final List<FoodItem> meals;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final List<double> weeklyData;
  final DateTime? selectedDate;
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final DateTime? lastUpdate;
  final int waterGlasses;
  final int waterGoal;

  const FoodLogState({
    this.meals = const [],
    this.totalCalories = 0,
    this.totalProtein = 0,
    this.totalCarbs = 0,
    this.totalFat = 0,
    this.weeklyData = const [],
    this.selectedDate,
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.lastUpdate,
    this.waterGlasses = 0,
    this.waterGoal = 8,
  });

  FoodLogState copyWith({
    List<FoodItem>? meals,
    double? totalCalories,
    double? totalProtein,
    double? totalCarbs,
    double? totalFat,
    List<double>? weeklyData,
    DateTime? selectedDate,
    bool? isLoading,
    String? error,
    String? successMessage,
    DateTime? lastUpdate,
    int? waterGlasses,
    int? waterGoal,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return FoodLogState(
      meals: meals ?? this.meals,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProtein: totalProtein ?? this.totalProtein,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      totalFat: totalFat ?? this.totalFat,
      weeklyData: weeklyData ?? this.weeklyData,
      selectedDate: selectedDate ?? this.selectedDate,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
      lastUpdate: lastUpdate ?? this.lastUpdate,
      waterGlasses: waterGlasses ?? this.waterGlasses,
      waterGoal: waterGoal ?? this.waterGoal,
    );
  }
}

class FoodLogCubit extends Cubit<FoodLogState> {
  final FoodRepository _repository;
  List<double>? _cachedWeeklyData;
  DateTime? _cachedWeeklyDataDate;
  SharedPreferences? _prefs;
  static const String _waterKey = 'water_glasses_';

  FoodLogCubit(this._repository) : super(const FoodLogState());

  /// Punto de acceso al repositorio para las pantallas que necesitan
  /// consultas por rango (Progreso) sin duplicar la instancia.
  FoodRepository get repository => _repository;

  Future<SharedPreferences> get _getPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> loadDailyLog() async {
    await loadLogForDate(DateTime.now());
  }

  Future<void> loadLogForDate(DateTime date) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    try {
      final meals = await _repository.getDailyFoodLog(date);
      final totals = _calculateTotals(meals);
      final waterGlasses = await _loadWaterGlasses(date);

      // Sincroniza la proteína real del registro con MacroBridge (multiplicador
      // x1.2 de HEAVY). Antes nunca se llamaba y el perfil mostraba siempre 0 g.
      _syncProteinToMacroBridge(totals['protein'] ?? 0.0, date);

      emit(state.copyWith(
        meals: meals,
        totalCalories: totals['calories'],
        totalProtein: totals['protein'],
        totalCarbs: totals['carbs'],
        totalFat: totals['fat'],
        weeklyData: const [],
        selectedDate: date,
        isLoading: false,
        lastUpdate: DateTime.now(),
        waterGlasses: waterGlasses,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  /// ÚNICO punto de sincronización proteína → Symmetry (multiplicador x1.2).
  /// Se ejecuta cada vez que se carga un registro diario (hoy u otro día) y
  /// no debe romper el registro de comida si el bridge falla.
  ///
  /// Antes existía también SymmetryProgressionService.syncProteinFromFoodLog,
  /// un segundo camino muerto que nadie llamaba; se eliminó para que solo
  /// quede este (FoodLogCubit → MacroBridge).
  void _syncProteinToMacroBridge(double totalProtein, DateTime date) {
    try {
      final macro = MacroBridge();
      macro.initialize().then((_) {
        macro.syncFromFoodLog(totalProtein: totalProtein, date: date);
      }).catchError((_) {});
    } catch (_) {}
  }

  Future<int> _loadWaterGlasses(DateTime date) async {
    final prefs = await _getPrefs;
    final key = '$_waterKey${formatDateKey(date)}';
    return prefs.getInt(key) ?? 0;
  }

  Future<void> _saveWaterGlasses(DateTime date, int glasses) async {
    final prefs = await _getPrefs;
    final key = '$_waterKey${formatDateKey(date)}';
    await prefs.setInt(key, glasses);
  }

  Future<void> addWaterGlass() async {
    final newCount = state.waterGlasses + 1;
    await _saveWaterGlasses(state.selectedDate ?? DateTime.now(), newCount);
    emit(state.copyWith(waterGlasses: newCount));
  }

  Future<void> removeWaterGlass() async {
    if (state.waterGlasses > 0) {
      final newCount = state.waterGlasses - 1;
      await _saveWaterGlasses(state.selectedDate ?? DateTime.now(), newCount);
      emit(state.copyWith(waterGlasses: newCount));
    }
  }

  Future<void> resetWater() async {
    await _saveWaterGlasses(state.selectedDate ?? DateTime.now(), 0);
    emit(state.copyWith(waterGlasses: 0));
  }

  Future<void> loadWeeklySummary() async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    try {
      final meals = await _repository.getDailyFoodLog(DateTime.now());
      final totals = _calculateTotals(meals);
      final weeklyData = await _loadWeeklyData();

      emit(state.copyWith(
        meals: meals,
        totalCalories: totals['calories'],
        totalProtein: totals['protein'],
        totalCarbs: totals['carbs'],
        totalFat: totals['fat'],
        weeklyData: weeklyData,
        selectedDate: null,
        isLoading: false,
        lastUpdate: DateTime.now(),
      ));
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  Future<void> addMeal(FoodItem meal) async {
    try {
      await _repository.addFoodItem(meal);
      _invalidateWeeklyCache();
      await loadDailyLog();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Map<String, double> _calculateTotals(List<FoodItem> meals) {
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    for (final meal in meals) {
      calories += meal.calories;
      protein += meal.protein;
      carbs += meal.carbs;
      fat += meal.fat;
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  void _invalidateWeeklyCache() {
    _cachedWeeklyData = null;
    _cachedWeeklyDataDate = null;
  }

  Future<List<double>> _loadWeeklyData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_cachedWeeklyData != null && _cachedWeeklyDataDate != null) {
      final cachedDay = DateTime(
        _cachedWeeklyDataDate!.year,
        _cachedWeeklyDataDate!.month,
        _cachedWeeklyDataDate!.day,
      );
      if (cachedDay == today) {
        return _cachedWeeklyData!;
      }
    }

    final List<double> weeklyData = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final meals = await _repository.getDailyFoodLog(date);
      final calories = _calculateTotals(meals)['calories'] ?? 0.0;
      weeklyData.add(calories);
    }

    _cachedWeeklyData = weeklyData;
    _cachedWeeklyDataDate = now;
    return weeklyData;
  }

  Future<void> addMealFromImage(Uint8List imageBytes) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));

    final result = await _repository.detectFoodFromImage(imageBytes);

    result.fold(
      (failure) {
        emit(state.copyWith(
          error: failure,
          isLoading: false,
        ));
      },
      (meal) async {
        await addMeal(meal);
        emit(state.copyWith(
          successMessage: 'Food "${meal.name}" detected successfully!',
          isLoading: false,
        ));
      },
    );
  }

  void clearMessages() {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }

  Future<void> deleteMeal(FoodItem meal) async {
    try {
      await _repository.deleteFoodItem(meal);
      _invalidateWeeklyCache();
      await loadDailyLog();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> updateMealName(String mealId, String newName) async {
    try {
      final existingMeal = state.meals.firstWhere((m) => m.id == mealId);
      final updatedMeal = existingMeal.copyWith(name: newName);
      await _repository.updateFoodItem(updatedMeal);
      _invalidateWeeklyCache();
      await loadDailyLog();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> updateMeal(FoodItem meal) async {
    try {
      await _repository.updateFoodItem(meal);
      _invalidateWeeklyCache();
      await loadDailyLog();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
