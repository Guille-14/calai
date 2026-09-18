import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/symmetry/macro_bridge.dart';
import '../../core/utils/date_key.dart';
import '../../data/models/food_item.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/services/google_fit_service.dart';

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
    bool clearSelectedDate = false,
  }) {
    return FoodLogState(
      meals: meals ?? this.meals,
      totalCalories: totalCalories ?? this.totalCalories,
      totalProtein: totalProtein ?? this.totalProtein,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      totalFat: totalFat ?? this.totalFat,
      weeklyData: weeklyData ?? this.weeklyData,
      selectedDate:
          clearSelectedDate ? null : (selectedDate ?? this.selectedDate),
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
  int _loadGeneration = 0;
  Future<void> _waterWrite = Future<void>.value();
  Future<void> _foodWrite = Future<void>.value();
  static const String _waterKey = 'water_glasses_';

  FoodLogCubit(this._repository) : super(const FoodLogState());

  /// Punto de acceso al repositorio para las pantallas que necesitan
  /// consultas por rango (Progreso) sin duplicar la instancia.
  FoodRepository get repository => _repository;

  /// Emisión segura: un Cubit cerrado lanza `StateError` si recibe `emit`.
  /// Como casi todas las operaciones son asíncronas (SQLite, prefs, IA), la
  /// respuesta puede llegar cuando la pantalla que abrió el cubit ya se
  /// desmontó. Antes eso tiraba la app; ahora el resultado tardío se
  /// descarta en silencio.
  void _safeEmit(FoodLogState newState) {
    if (isClosed) return;
    emit(newState);
  }

  Future<SharedPreferences> get _getPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> loadDailyLog() async {
    await loadLogForDate(DateTime.now());
  }

  Future<void> loadLogForDate(DateTime date) async {
    final generation = ++_loadGeneration;
    _safeEmit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    try {
      final meals = await _repository.getDailyFoodLog(date);
      final totals = _calculateTotals(meals);
      final waterGlasses = await _loadWaterGlasses(date);
      if (generation != _loadGeneration) return;

      // Sincroniza la proteína real del registro con MacroBridge (multiplicador
      // x1.2 de HEAVY). Se espera para que el dashboard no lea un valor
      // anterior justo después de guardar una comida.
      await _syncProteinToMacroBridge(totals['protein'] ?? 0.0, date);

      _safeEmit(state.copyWith(
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
      if (generation != _loadGeneration) return;
      _safeEmit(state.copyWith(
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
  Future<void> _syncProteinToMacroBridge(
      double totalProtein, DateTime date) async {
    try {
      final macro = MacroBridge();
      await macro.initialize();
      await macro.syncFromFoodLog(totalProtein: totalProtein, date: date);
    } catch (_) {
      // La sincronización es auxiliar: nunca debe convertir una comida válida
      // en un error de carga del registro.
    }
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

  /// Serializa las escrituras para que varios taps rápidos no se pierdan.
  /// La UI se actualiza de forma optimista y la persistencia se procesa en
  /// orden, manteniendo el contador fluido incluso con un canal lento.
  Future<void> _enqueueWaterWrite(DateTime date, int glasses) {
    final operation = _waterWrite.then<void>((_) {
      return _saveWaterGlasses(date, glasses);
    });
    _waterWrite = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }

  Future<void> _optimisticWaterChange(int newCount) async {
    final previousCount = state.waterGlasses;
    final date = state.selectedDate ?? DateTime.now();
    if (!isClosed) _safeEmit(state.copyWith(waterGlasses: newCount));
    try {
      await _enqueueWaterWrite(date, newCount);
    } catch (error) {
      // Si no hubo otro tap posterior, revertimos; si lo hubo, no pisamos su
      // valor optimista y dejamos que la cola termine de persistirlo.
      if (!isClosed && state.waterGlasses == newCount) {
        _safeEmit(state.copyWith(waterGlasses: previousCount, error: error.toString()));
      }
    }
  }

  Future<void> addWaterGlass() async {
    await _optimisticWaterChange(state.waterGlasses + 1);
  }

  Future<void> removeWaterGlass() async {
    if (state.waterGlasses > 0) {
      await _optimisticWaterChange(state.waterGlasses - 1);
    }
  }

  Future<void> resetWater() async {
    await _optimisticWaterChange(0);
  }

  Future<void> loadWeeklySummary() async {
    final generation = ++_loadGeneration;
    _safeEmit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    try {
      final meals = await _repository.getDailyFoodLog(DateTime.now());
      final totals = _calculateTotals(meals);
      final weeklyData = await _loadWeeklyData();
      if (generation != _loadGeneration) return;

      _safeEmit(state.copyWith(
        meals: meals,
        totalCalories: totals['calories'],
        totalProtein: totals['protein'],
        totalCarbs: totals['carbs'],
        totalFat: totals['fat'],
        weeklyData: weeklyData,
        clearSelectedDate: true,
        isLoading: false,
        lastUpdate: DateTime.now(),
      ));
    } catch (e) {
      if (generation != _loadGeneration) return;
      _safeEmit(state.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  FoodLogState _stateWithMeals(
    List<FoodItem> meals, {
    String? error,
  }) {
    final totals = _calculateTotals(meals);
    return state.copyWith(
      meals: List.unmodifiable(meals),
      totalCalories: totals['calories'],
      totalProtein: totals['protein'],
      totalCarbs: totals['carbs'],
      totalFat: totals['fat'],
      isLoading: false,
      lastUpdate: DateTime.now(),
      error: error,
      clearError: error == null,
      clearSuccess: true,
    );
  }

  Future<void> _enqueueFoodWrite(Future<void> Function() operation) {
    final queued = _foodWrite.then<void>((_) => operation());
    _foodWrite = queued.then<void>((_) {}, onError: (_) {});
    return queued;
  }

  Future<void> addMeal(FoodItem meal) async {
    final previousMeals = state.meals;
    final operationGeneration = ++_loadGeneration;
    _safeEmit(_stateWithMeals([...previousMeals, meal]));

    try {
      await _enqueueFoodWrite(() => _repository.addFoodItem(meal));
      _invalidateWeeklyCache();
      _publishMealToHealthConnect(meal);
    } catch (error) {
      if (!isClosed && operationGeneration == _loadGeneration) {
        _safeEmit(_stateWithMeals(previousMeals, error: error.toString()));
      }
    }
  }

  /// Publica la comida en Health Connect para que el resto de apps de salud
  /// la vean (sincronización bidireccional: CalAI ya leía pasos y calorías,
  /// pero no aportaba nada).
  ///
  /// Es best-effort y no se espera: si Health Connect no está instalado, el
  /// usuario no dio permiso de escritura o la llamada falla, la comida ya
  /// está guardada en CalAI y no debe verse afectada.
  void _publishMealToHealthConnect(FoodItem meal) {
    unawaited(GoogleFitService.instance.writeMealToHealthConnect(
      name: meal.name,
      calories: meal.calories,
      protein: meal.protein,
      carbs: meal.carbs,
      fat: meal.fat,
      sugar: meal.sugar,
      timestamp: meal.timestamp,
    ));
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

    // Una única lectura del rango reemplaza las siete consultas secuenciales
    // que se hacían al abrir el resumen semanal.
    final start = today.subtract(const Duration(days: 6));
    final meals = await _repository.getFoodLogForRange(start, today);
    final caloriesByDay = <String, double>{};
    for (final meal in meals) {
      final key = formatDateKey(meal.timestamp);
      caloriesByDay[key] = (caloriesByDay[key] ?? 0) + meal.calories;
    }
    final weeklyData = <double>[];
    for (var i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      weeklyData.add(caloriesByDay[formatDateKey(date)] ?? 0.0);
    }

    _cachedWeeklyData = weeklyData;
    _cachedWeeklyDataDate = now;
    return weeklyData;
  }

  Future<void> addMealFromImage(Uint8List imageBytes) async {
    _safeEmit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));

    // `detectFoodFromImage` habla con la IA: puede lanzar (red caída, timeout,
    // respuesta ilegible). Sin este try la excepción escapaba del cubit hacia
    // la zona global y dejaba `isLoading: true` para siempre.
    FoodItem? meal;
    String? failureMessage;
    try {
      final result = await _repository.detectFoodFromImage(imageBytes);
      // `fold` es síncrono: pasarle un callback `async` devolvía un Future que
      // nadie esperaba ni capturaba, así que un fallo al guardar la comida se
      // convertía en un error asíncrono no gestionado. Aquí solo se extraen
      // los valores y el trabajo asíncrono se hace fuera, con await.
      result.fold(
        (failure) => failureMessage = failure,
        (value) => meal = value,
      );
    } catch (error) {
      _safeEmit(state.copyWith(error: error.toString(), isLoading: false));
      return;
    }

    final detected = meal;
    if (detected == null) {
      _safeEmit(state.copyWith(
        error: failureMessage ?? 'Error en el análisis',
        isLoading: false,
      ));
      return;
    }

    await addMeal(detected);
    _safeEmit(state.copyWith(
      successMessage: 'Food "${detected.name}" detected successfully!',
      isLoading: false,
    ));
  }

  void clearMessages() {
    _safeEmit(state.copyWith(clearError: true, clearSuccess: true));
  }

  Future<void> deleteMeal(FoodItem meal) async {
    final previousMeals = state.meals;
    final optimisticMeals = previousMeals.where((item) => item.id != meal.id).toList();
    final operationGeneration = ++_loadGeneration;
    _safeEmit(_stateWithMeals(optimisticMeals));

    try {
      await _enqueueFoodWrite(() => _repository.deleteFoodItem(meal));
      _invalidateWeeklyCache();
      // Mismo instante con el que se escribió: así no quedan registros
      // huérfanos en Health Connect al borrar la comida en CalAI.
      unawaited(GoogleFitService.instance
          .deleteMealFromHealthConnect(meal.timestamp));
    } catch (error) {
      if (!isClosed && operationGeneration == _loadGeneration) {
        _safeEmit(_stateWithMeals(previousMeals, error: error.toString()));
      }
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
      _safeEmit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> updateMeal(FoodItem meal) async {
    try {
      await _repository.updateFoodItem(meal);
      _invalidateWeeklyCache();
      await loadDailyLog();
    } catch (e) {
      _safeEmit(state.copyWith(error: e.toString()));
    }
  }
}
