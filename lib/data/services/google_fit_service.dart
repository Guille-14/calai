import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/symmetry/symmetry_workout_ledger.dart';
import 'database_service.dart';

/// Integración real con Android Health Connect.
///
/// El nombre se conserva por compatibilidad con la UI antigua, pero no habla
/// con Google Fit. Health Connect solo puede devolver lo que cada aplicación
/// haya escrito allí: si Mi Fitness no publica series de ejercicios, no es
/// posible inventar sus series, pesos o repeticiones desde este plugin.
class GoogleFitService {
  GoogleFitService._privateConstructor();

  static final GoogleFitService _instance =
      GoogleFitService._privateConstructor();
  static GoogleFitService get instance => _instance;

  static const String lastImportedAtKey = 'health_connect_last_imported_at';
  static const String _importedCountKey = 'health_connect_imported_count';

  Health? _healthInstance;
  Health get _health => _healthInstance ??= Health();

  bool _isAuthorized = false;
  DateTime? _lastSyncTime;
  bool _isConfigured = false;
  List<WorkoutSession> _lastImportedSessions = const [];

  List<WorkoutSession> get lastImportedSessions =>
      List.unmodifiable(_lastImportedSessions);

  bool get isAuthorized => _isAuthorized;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isConfigured => _isConfigured;

  /// Tipos que alimentan el panel diario y el histórico.
  /// Cada tipo se lee por separado: si el usuario no concede sueño o pulso,
  /// eso no bloquea pasos, calorías o entrenamientos.
  static const List<HealthDataType> _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.WORKOUT,
    HealthDataType.WEIGHT,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.HEIGHT,
    HealthDataType.LEAN_BODY_MASS,
    HealthDataType.WATER,
  ];

  List<HealthDataType> get supportedHistoryTypes =>
      List.unmodifiable(_readTypes);

  Future<bool> configureHealth() async {
    if (!Platform.isAndroid) {
      debugPrint('GoogleFitService: Health Connect solo está disponible en Android');
      return false;
    }
    try {
      await _health.configure();
      _isConfigured = true;
      return true;
    } catch (e) {
      debugPrint('GoogleFitService: error configurando Health Connect: $e');
      return false;
    }
  }

  Future<bool> requestAuthorization() async {
    if (!Platform.isAndroid) return false;
    try {
      if (!_isConfigured && !await configureHealth()) return false;
      _isAuthorized = await _health.requestAuthorization(
        _readTypes,
        permissions: List<HealthDataAccess>.filled(
          _readTypes.length,
          HealthDataAccess.READ,
        ),
      );
      return _isAuthorized;
    } catch (e) {
      debugPrint('GoogleFitService: error solicitando permisos: $e');
      _isAuthorized = false;
      return false;
    }
  }

  Future<bool> checkAuthorization() async {
    if (!Platform.isAndroid) return false;
    try {
      if (!_isConfigured && !await configureHealth()) return false;
      _isAuthorized = await _health.hasPermissions(_readTypes) == true;
      return _isAuthorized;
    } catch (e) {
      debugPrint('GoogleFitService: error comprobando permisos: $e');
      _isAuthorized = false;
      return false;
    }
  }

  Future<bool> _ensureAuthorization() async {
    if (await checkAuthorization()) return true;
    return requestAuthorization();
  }

  Future<bool> _ensureHistoricalAuthorization() async {
    if (!await _ensureAuthorization()) return false;
    try {
      if (!await _health.isHealthDataHistoryAvailable()) return true;
      if (await _health.isHealthDataHistoryAuthorized()) return true;
      return await _health.requestHealthDataHistoryAuthorization();
    } catch (e) {
      debugPrint('GoogleFitService: no se pudo solicitar histórico: $e');
      return false;
    }
  }

  Future<bool> isHealthConnectInstalled() async {
    if (!Platform.isAndroid) return false;
    try {
      if (!_isConfigured) await configureHealth();
      return await _health.isHealthConnectAvailable();
    } catch (e) {
      debugPrint('GoogleFitService: error comprobando instalación: $e');
      return false;
    }
  }

  double _extractNumericValue(HealthValue value) {
    if (value is NumericHealthValue) return value.numericValue.toDouble();
    return 0;
  }

  Future<GoogleFitDailyData> fetchDailyData() async {
    if (!Platform.isAndroid) {
      return GoogleFitDailyData.error('Solo Android soportado');
    }
    try {
      if (!await _ensureAuthorization()) {
        return GoogleFitDailyData.error(
            'No autorizado. Abre Perfil > Health Connect y concede los permisos.');
      }
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final points = await Future.wait([
        _readType(HealthDataType.ACTIVE_ENERGY_BURNED, startOfDay, now),
        _readType(HealthDataType.BASAL_ENERGY_BURNED, startOfDay, now),
        _readType(HealthDataType.DISTANCE_DELTA, startOfDay, now),
      ]);
      final steps = await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;
      final activeCalories = points[0]
          .fold<double>(0, (sum, point) => sum + _extractNumericValue(point.value));
      final basalCalories = points[1]
          .fold<double>(0, (sum, point) => sum + _extractNumericValue(point.value));
      final distanceMeters = points[2]
          .fold<double>(0, (sum, point) => sum + _extractNumericValue(point.value));
      _lastSyncTime = DateTime.now();
      return GoogleFitDailyData(
        steps: steps,
        activeCalories: (activeCalories + basalCalories).round(),
        activeCaloriesOnly: activeCalories.round(),
        basalCalories: basalCalories.round(),
        distanceKm: distanceMeters / 1000,
        lastSync: _lastSyncTime!,
        deviceName: 'Health Connect',
      );
    } catch (e) {
      return GoogleFitDailyData.error('Error leyendo Health Connect: $e');
    }
  }

  Future<List<HealthDataPoint>> _readType(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [type],
      );
      // Health Connect puede entregar el mismo registro por más de un origen.
      return _health.removeDuplicates(points);
    } catch (e) {
      debugPrint('GoogleFitService: no se pudo leer $type: $e');
      return const [];
    }
  }

  /// Importa todos los tipos disponibles en Health Connect y guarda:
  /// - sesiones de ejercicio con UUID, fuente, actividad, calorías, distancia
  ///   y pasos cuando el origen los publica;
  /// - resúmenes diarios de pasos, calorías, distancia, peso, sueño y pulso.
  ///
  /// No concede XP: una sesión externa se muestra como importada para evitar
  /// duplicar la progresión de una sesión introducida en Symmetry.
  Future<HealthImportResult> importFullHistory({DateTime? since}) async {
    if (!Platform.isAndroid) {
      return HealthImportResult.error('Solo Android soportado');
    }
    if (!await _ensureHistoricalAuthorization()) {
      return HealthImportResult.error(
          'Health Connect no ha concedido el acceso al histórico. Abre la pantalla de permisos y activa "Datos de salud históricos".');
    }

    final prefs = await SharedPreferences.getInstance();
    final savedSince = prefs.getInt(lastImportedAtKey);
    final start = since ??
        (savedSince == null
            ? DateTime.now().subtract(const Duration(days: 3650))
            // Re-read the tail of the previous window so a record written
            // late by Mi Fitness cannot erase the current day's summary.
            : DateTime.fromMillisecondsSinceEpoch(savedSince)
                .subtract(const Duration(days: 2)));
    final end = DateTime.now();

    final results = await Future.wait(
      _readTypes.map((type) => _readType(type, start, end)),
    );
    final byType = <HealthDataType, List<HealthDataPoint>>{
      for (var i = 0; i < _readTypes.length; i++) _readTypes[i]: results[i],
    };
    final workouts = byType[HealthDataType.WORKOUT] ?? const [];
    final sessions = workouts.map(_toWorkoutSession).toList();
    _lastImportedSessions = sessions;

    final db = DatabaseService();
    final idsBySource = <String, Set<String>>{};
    for (final session in sessions) {
      final externalId = session.externalId;
      if (externalId != null) {
        idsBySource.putIfAbsent(session.source, () => <String>{}).add(externalId);
      }
    }
    final existingIds = <String>{};
    for (final entry in idsBySource.entries) {
      final ids = await db.getExistingWorkoutExternalIds(entry.key, entry.value);
      existingIds.addAll(ids.map((id) => '${entry.key}|$id'));
    }

    var insertedWorkouts = 0;
    final seenIds = <String>{};
    for (final session in sessions) {
      final externalId = session.externalId;
      final uniqueKey = externalId == null
          ? null
          : '${session.source}|$externalId';
      if (uniqueKey != null &&
          (existingIds.contains(uniqueKey) || !seenIds.add(uniqueKey))) {
        continue;
      }
      await db.insertWorkoutSession(
        date: session.date,
        totalTonnage: session.totalTonnage,
        durationMinutes: session.durationMinutes,
        muscleGroupTonnage: session.muscleGroupTonnage,
        xpEarned: 0,
        source: session.source,
        externalId: externalId,
        importedAt: end,
        caloriesBurned: session.caloriesBurned,
        distanceMeters: session.distanceMeters,
        steps: session.steps.toDouble(),
        activityName: session.exercises.isEmpty ? null : session.exercises.first.name,
      );
      insertedWorkouts++;
    }

    final accumulators = <String, _DailyHealthAccumulator>{};
    for (final entry in byType.entries) {
      for (final point in entry.value) {
        _accumulate(accumulators, entry.key, point);
      }
    }
    for (final item in accumulators.values) {
      await db.upsertHealthDailyMetric(
        date: item.date,
        source: item.source,
        steps: item.steps,
        activeCalories: item.activeCalories,
        basalCalories: item.basalCalories,
        distanceMeters: item.distanceMeters,
        weightKg: item.weightKg,
        sleepMinutes: item.sleepMinutes,
        sleepSessions: item.sleepSessions,
        heartRateAverage: item.heartRateAverage,
        heartRateMin: item.heartRateMin,
        heartRateMax: item.heartRateMax,
        heartRateSamples: item.heartRateSamples,
        workouts: item.workouts,
        otherMetrics: item.otherMetrics,
        importedAt: end,
      );
    }

    await prefs.setInt(lastImportedAtKey, end.millisecondsSinceEpoch);
    await prefs.setInt(
      _importedCountKey,
      (prefs.getInt(_importedCountKey) ?? 0) + insertedWorkouts,
    );
    _lastSyncTime = end;

    final allPoints = byType.values.expand((points) => points).toList();
    final sourcePointCounts = <String, int>{};
    for (final point in allPoints) {
      final source = _sourceFor(point.sourceName);
      sourcePointCounts[source] = (sourcePointCounts[source] ?? 0) + 1;
    }
    DateTime? availableFrom;
    DateTime? availableTo;
    for (final point in allPoints) {
      if (availableFrom == null || point.dateFrom.isBefore(availableFrom)) {
        availableFrom = point.dateFrom;
      }
      if (availableTo == null || point.dateTo.isAfter(availableTo)) {
        availableTo = point.dateTo;
      }
    }

    final stepPoints = byType[HealthDataType.STEPS] ?? const [];
    final activePoints = byType[HealthDataType.ACTIVE_ENERGY_BURNED] ?? const [];
    final distancePoints = byType[HealthDataType.DISTANCE_DELTA] ?? const [];
    final activeCalories = activePoints.fold<double>(
        0, (sum, point) => sum + _extractNumericValue(point.value));
    final distanceMeters = distancePoints.fold<double>(
        0, (sum, point) => sum + _extractNumericValue(point.value));
    final totalSteps = stepPoints.fold<double>(
        0, (sum, point) => sum + _extractNumericValue(point.value));

    return HealthImportResult(
      isSuccess: true,
      importedWorkouts: insertedWorkouts,
      totalWorkoutRecords: workouts.length,
      weightRecords: (byType[HealthDataType.WEIGHT] ?? const []).length,
      sleepSessions: (byType[HealthDataType.SLEEP_SESSION] ?? const []).length,
      heartRateRecords: (byType[HealthDataType.HEART_RATE] ?? const []).length,
      stepsRecords: stepPoints.length,
      activeCaloriesRecords: activePoints.length,
      totalCaloriesRecords:
          (byType[HealthDataType.TOTAL_CALORIES_BURNED] ?? const []).length,
      distanceRecords: distancePoints.length,
      healthDays: accumulators.length,
      totalSteps: totalSteps.round(),
      activeCalories: activeCalories.round(),
      distanceKm: distanceMeters / 1000,
      sourcePointCounts: sourcePointCounts,
      availableFrom: availableFrom,
      availableTo: availableTo,
      lastImportedAt: end,
    );
  }

  void _accumulate(
    Map<String, _DailyHealthAccumulator> accumulators,
    HealthDataType type,
    HealthDataPoint point,
  ) {
    final source = _sourceFor(point.sourceName);
    final day = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
    final key = '${day.toIso8601String()}|$source';
    final item = accumulators.putIfAbsent(
      key,
      () => _DailyHealthAccumulator(date: day, source: source),
    );
    final numeric = _extractNumericValue(point.value);

    switch (type) {
      case HealthDataType.STEPS:
        item.steps += numeric.round();
        break;
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        item.activeCalories += numeric;
        break;
      case HealthDataType.BASAL_ENERGY_BURNED:
        item.basalCalories += numeric;
        break;
      case HealthDataType.DISTANCE_DELTA:
        item.distanceMeters += numeric;
        break;
      case HealthDataType.WORKOUT:
        // Las calorías/distancia/pasos del workout son métricas de la sesión.
        // No se suman al resumen diario porque normalmente también llegan como
        // ACTIVE_ENERGY_BURNED, DISTANCE_DELTA y STEPS y se duplicarían.
        item.workouts++;
        break;
      case HealthDataType.WEIGHT:
        item.weightKg = numeric;
        break;
      case HealthDataType.SLEEP_SESSION:
        item.sleepSessions++;
        item.sleepMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
        break;
      case HealthDataType.HEART_RATE:
      case HealthDataType.RESTING_HEART_RATE:
        item.addHeartRate(numeric);
        break;
      // These records are read and contribute to the available-data range. A
      // later schema version can expose their individual values without
      // discarding them from the sync result.
      case HealthDataType.BLOOD_OXYGEN:
      case HealthDataType.BODY_FAT_PERCENTAGE:
      case HealthDataType.HEIGHT:
      case HealthDataType.LEAN_BODY_MASS:
      case HealthDataType.WATER:
      case HealthDataType.FLIGHTS_CLIMBED:
      case HealthDataType.TOTAL_CALORIES_BURNED:
        _addOtherMetric(item, type, point, numeric);
        break;
      default:
        break;
    }
  }

  void _addOtherMetric(
    _DailyHealthAccumulator item,
    HealthDataType type,
    HealthDataPoint point,
    double numeric,
  ) {
    final key = type.toString().split('.').last;
    final previous = item.otherMetrics[key];
    final summary = previous is Map
        ? Map<String, dynamic>.from(previous)
        : <String, dynamic>{};
    final lastValueTypes = {
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.BODY_FAT_PERCENTAGE,
      HealthDataType.HEIGHT,
      HealthDataType.LEAN_BODY_MASS,
    };
    final previousValue = (summary['value'] as num?)?.toDouble() ?? 0;
    summary['value'] = lastValueTypes.contains(type)
        ? numeric
        : previousValue + numeric;
    summary['unit'] = _unitFor(type);
    summary['records'] = ((summary['records'] as num?)?.toInt() ?? 0) + 1;
    final from = summary['intervalFrom']?.toString();
    final to = summary['intervalTo']?.toString();
    final pointFrom = point.dateFrom.toIso8601String();
    final pointTo = point.dateTo.toIso8601String();
    summary['intervalFrom'] = from == null || pointFrom.compareTo(from) < 0
        ? pointFrom
        : from;
    summary['intervalTo'] = to == null || pointTo.compareTo(to) > 0 ? pointTo : to;
    item.otherMetrics[key] = summary;
  }

  String _unitFor(HealthDataType type) {
    switch (type) {
      case HealthDataType.BLOOD_OXYGEN:
      case HealthDataType.BODY_FAT_PERCENTAGE:
        return '%';
      case HealthDataType.HEIGHT:
        return 'm';
      case HealthDataType.LEAN_BODY_MASS:
        return 'kg';
      case HealthDataType.WATER:
        return 'L';
      case HealthDataType.TOTAL_CALORIES_BURNED:
        return 'kcal';
      case HealthDataType.FLIGHTS_CLIMBED:
        return 'pisos';
      default:
        return 'unidad';
    }
  }

  WorkoutSession _toWorkoutSession(HealthDataPoint point) {
    final duration = point.dateTo.difference(point.dateFrom).inMinutes;
    final safeDuration = duration < 0 ? 0 : duration;
    final activity = point.value is WorkoutHealthValue
        ? (point.value as WorkoutHealthValue).workoutActivityType.toString()
        : 'Workout';
    final displayActivity = activity.replaceFirst('HealthWorkoutActivityType.', '');
    final source = _sourceFor(point.sourceName);
    final externalId = '$source|${point.uuid}';
    final calories = point.value is WorkoutHealthValue
        ? (point.value as WorkoutHealthValue).totalEnergyBurned?.toDouble() ?? 0.0
        : 0.0;
    final distance = point.value is WorkoutHealthValue
        ? (point.value as WorkoutHealthValue).totalDistance?.toDouble() ?? 0.0
        : 0.0;
    final steps = point.value is WorkoutHealthValue
        ? (point.value as WorkoutHealthValue).totalSteps ?? 0
        : 0;
    final group = _groupFor(displayActivity);

    // Health Connect no ofrece normalmente series, peso, sets o repeticiones.
    // Por eso no se presenta tonelaje inventado: se guardan los datos reales
    // de la sesión y la pantalla la etiqueta como actividad importada.
    return WorkoutSession(
      date: point.dateFrom,
      totalTonnage: 0,
      durationMinutes: safeDuration,
      muscleGroupTonnage: {group: 0},
      exercises: [
        ExerciseRecord(
          name: displayActivity,
          muscleGroup: group,
          weight: 0,
          sets: 0,
          reps: 0,
        ),
      ],
      source: source,
      externalId: externalId,
      caloriesBurned: calories,
      distanceMeters: distance,
      steps: steps,
    );
  }

  String _sourceFor(String sourceName) {
    final source = sourceName.toLowerCase();
    if (source.contains('mifit') ||
        source.contains('mi fitness') ||
        source.contains('mi_fitness') ||
        source.contains('xiaomi') ||
        source.contains('zepp') ||
        source.contains('amazfit')) {
      return 'mifit';
    }
    if (source.contains('symmetry')) return 'symmetry_app';
    if (source.contains('hevy')) return 'hevy';
    final provider = sourceName.trim();
    if (provider.isEmpty) return 'health_connect';
    // No escondemos una aplicación desconocida bajo el genérico
    // "health_connect": el nombre real permite distinguir proveedores que
    // no conocemos todavía y comprobar manualmente si Symmetry publica datos.
    final safeProvider = provider.replaceAll(RegExp(r'\s+'), '_');
    return 'health_connect:$safeProvider';
  }

  String _groupFor(String activity) {
    final value = activity.toLowerCase();
    if (value.contains('run') || value.contains('walk') || value.contains('bike') || value.contains('cycle')) {
      return 'cardio';
    }
    if (value.contains('leg') || value.contains('squat')) return 'cuadriceps';
    if (value.contains('press') || value.contains('push')) return 'pecho';
    if (value.contains('row') || value.contains('pull')) return 'espalda';
    return 'general';
  }

  Future<void> revokeAccess() async {
    try {
      await _health.revokePermissions();
      _isAuthorized = false;
      _lastSyncTime = null;
    } catch (e) {
      debugPrint('GoogleFitService: error revocando permisos: $e');
    }
  }
}

class _DailyHealthAccumulator {
  final DateTime date;
  final String source;
  int steps = 0;
  double activeCalories = 0;
  double basalCalories = 0;
  double distanceMeters = 0;
  double? weightKg;
  double sleepMinutes = 0;
  int sleepSessions = 0;
  double? heartRateAverage;
  double? heartRateMin;
  double? heartRateMax;
  int heartRateSamples = 0;
  int workouts = 0;
  final Map<String, dynamic> otherMetrics = {};
  double _heartRateTotal = 0;

  _DailyHealthAccumulator({required this.date, required this.source});

  void addHeartRate(double value) {
    if (value <= 0) return;
    _heartRateTotal += value;
    heartRateSamples++;
    heartRateAverage = _heartRateTotal / heartRateSamples;
    heartRateMin = heartRateMin == null ? value : (value < heartRateMin! ? value : heartRateMin);
    heartRateMax = heartRateMax == null ? value : (value > heartRateMax! ? value : heartRateMax);
  }
}

class HealthImportResult {
  final bool isSuccess;
  final String? error;
  final int importedWorkouts;
  final int totalWorkoutRecords;
  final int weightRecords;
  final int sleepSessions;
  final int heartRateRecords;
  final int stepsRecords;
  final int activeCaloriesRecords;
  final int totalCaloriesRecords;
  final int distanceRecords;
  final int healthDays;
  final int totalSteps;
  final int activeCalories;
  final double distanceKm;
  final Map<String, int> sourcePointCounts;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final DateTime? lastImportedAt;

  const HealthImportResult({
    required this.isSuccess,
    this.error,
    this.importedWorkouts = 0,
    this.totalWorkoutRecords = 0,
    this.weightRecords = 0,
    this.sleepSessions = 0,
    this.heartRateRecords = 0,
    this.stepsRecords = 0,
    this.activeCaloriesRecords = 0,
    this.totalCaloriesRecords = 0,
    this.distanceRecords = 0,
    this.healthDays = 0,
    this.totalSteps = 0,
    this.activeCalories = 0,
    this.distanceKm = 0,
    this.sourcePointCounts = const {},
    this.availableFrom,
    this.availableTo,
    this.lastImportedAt,
  });

  factory HealthImportResult.error(String message) =>
      HealthImportResult(isSuccess: false, error: message);
}

class GoogleFitDailyData {
  final int steps;
  final int activeCalories;
  final int activeCaloriesOnly;
  final int basalCalories;
  final double distanceKm;
  final DateTime lastSync;
  final String? deviceName;
  final String? error;

  GoogleFitDailyData({
    required this.steps,
    required this.activeCalories,
    this.activeCaloriesOnly = 0,
    this.basalCalories = 0,
    required this.distanceKm,
    required this.lastSync,
    this.deviceName,
    this.error,
  });

  factory GoogleFitDailyData.error(String message) {
    return GoogleFitDailyData(
      steps: 0,
      activeCalories: 0,
      distanceKm: 0,
      lastSync: DateTime.now(),
      error: message,
    );
  }

  bool get hasError => error != null;
}
