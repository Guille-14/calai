import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/symmetry/symmetry_workout_ledger.dart';
import 'database_service.dart';

/// Bridge real con Android Health Connect.
///
/// El nombre GoogleFitService se conserva por compatibilidad histórica con la
/// UI, pero en Android el proveedor es Health Connect. Las sesiones importadas
/// no dan XP: no pasan por una sesión guiada y así no se duplica progreso.
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
  List<WorkoutSession> _lastImportedSessions = [];

  List<WorkoutSession> get lastImportedSessions =>
      List.unmodifiable(_lastImportedSessions);

  bool get isAuthorized => _isAuthorized;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isConfigured => _isConfigured;

  static const List<HealthDataType> _coreTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
  ];

  static const List<HealthDataType> _historyTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.WEIGHT,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.HEART_RATE,
  ];

  List<HealthDataType> get supportedHistoryTypes =>
      List.unmodifiable(_historyTypes);

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
      debugPrint('GoogleFitService: Configure error: $e');
      return false;
    }
  }

  Future<bool> requestAuthorization() async {
    if (!Platform.isAndroid) return false;
    try {
      if (!_isConfigured && !await configureHealth()) return false;
      final types = <HealthDataType>[..._coreTypes, ..._historyTypes];
      final permissions = List<HealthDataAccess>.filled(
        types.length,
        HealthDataAccess.READ,
      );
      _isAuthorized = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );
      return _isAuthorized;
    } catch (e) {
      debugPrint('GoogleFitService: Authorization error: $e');
      _isAuthorized = false;
      return false;
    }
  }

  Future<bool> checkAuthorization() async {
    if (!Platform.isAndroid) return false;
    try {
      if (!_isConfigured) await configureHealth();
      final types = <HealthDataType>[..._coreTypes, ..._historyTypes];
      _isAuthorized = await _health.hasPermissions(types) == true;
      return _isAuthorized;
    } catch (e) {
      debugPrint('GoogleFitService: Check auth error: $e');
      return false;
    }
  }

  Future<bool> _ensureAuthorization() async {
    if (await checkAuthorization()) return true;
    return requestAuthorization();
  }

  Future<bool> isHealthConnectInstalled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _health.isHealthConnectAvailable();
    } catch (e) {
      debugPrint('GoogleFitService: Check installed error: $e');
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
            'No autorizado. Conecta Health Connect.');
      }
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;

      var totalCalories = 0.0;
      for (final point in await _readType(
          HealthDataType.ACTIVE_ENERGY_BURNED, startOfDay, now)) {
        totalCalories += _extractNumericValue(point.value);
      }
      for (final point in await _readType(
          HealthDataType.BASAL_ENERGY_BURNED, startOfDay, now)) {
        totalCalories += _extractNumericValue(point.value);
      }

      var distanceKm = 0.0;
      for (final point in await _readType(
          HealthDataType.DISTANCE_DELTA, startOfDay, now)) {
        distanceKm += _extractNumericValue(point.value) / 1000;
      }
      _lastSyncTime = DateTime.now();
      return GoogleFitDailyData(
        steps: steps,
        activeCalories: totalCalories.round(),
        distanceKm: distanceKm,
        lastSync: _lastSyncTime!,
        deviceName: 'Health Connect',
      );
    } catch (e) {
      return GoogleFitDailyData.error('Error de sincronización: $e');
    }
  }

  Future<List<HealthDataPoint>> _readType(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      return await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [type],
      );
    } catch (e) {
      // Health Connect permite que el usuario no conceda cada tipo por
      // separado; una ausencia de sueño no debe impedir importar workouts.
      debugPrint('GoogleFitService: no se pudo leer $type: $e');
      return [];
    }
  }

  /// Importa el rango disponible y persiste solo sesiones nuevas.
  ///
  /// En la primera ejecución se solicita un rango amplio, pero Health Connect
  /// solo devuelve lo que conserva cada aplicación de origen. El resultado
  /// expone [availableFrom]/[availableTo] para que la UI no prometa años de
  /// histórico que el teléfono no tiene.
  Future<HealthImportResult> importFullHistory({DateTime? since}) async {
    if (!Platform.isAndroid) {
      return HealthImportResult.error('Solo Android soportado');
    }
    if (!await _ensureAuthorization()) {
      return HealthImportResult.error(
          'No autorizado. Conecta Health Connect desde Ajustes.');
    }

    final prefs = await SharedPreferences.getInstance();
    final savedSince = prefs.getInt(lastImportedAtKey);
    final start = since ??
        (savedSince == null
            ? DateTime.now().subtract(const Duration(days: 3650))
            : DateTime.fromMillisecondsSinceEpoch(savedSince));
    final end = DateTime.now();

    final workouts = await _readType(HealthDataType.WORKOUT, start, end);
    final weights = await _readType(HealthDataType.WEIGHT, start, end);
    final sleeps = await _readType(HealthDataType.SLEEP_SESSION, start, end);
    final heartRates = await _readType(HealthDataType.HEART_RATE, start, end);

    final sessions = workouts.map(_toWorkoutSession).toList();
    _lastImportedSessions = sessions;
    final db = DatabaseService();
    var inserted = 0;
    for (final session in sessions) {
      await db.insertWorkoutSession(
        date: session.date,
        totalTonnage: session.totalTonnage,
        durationMinutes: session.durationMinutes,
        muscleGroupTonnage: session.muscleGroupTonnage,
        // Diseño deliberado: los importados aparecen en historial pero no
        // conceden XP automático, porque no son sesiones guiadas de Symmetry.
        xpEarned: 0,
        source: session.source,
        externalId: session.externalId,
        importedAt: end,
      );
      inserted++;
    }

    // El timestamp marca el final de un sync correcto. Si algún tipo no está
    // disponible, el siguiente sync seguirá siendo seguro gracias al índice
    // source + external_id de las sesiones que sí se hayan recibido.
    await prefs.setInt(lastImportedAtKey, end.millisecondsSinceEpoch);
    final totalImported = (prefs.getInt(_importedCountKey) ?? 0) + inserted;
    await prefs.setInt(_importedCountKey, totalImported);
    _lastSyncTime = end;

    final allPoints = <HealthDataPoint>[
      ...workouts,
      ...weights,
      ...sleeps,
      ...heartRates,
    ];
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

    return HealthImportResult(
      importedWorkouts: inserted,
      weightRecords: weights.length,
      sleepSessions: sleeps.length,
      heartRateRecords: heartRates.length,
      availableFrom: availableFrom,
      availableTo: availableTo,
      lastImportedAt: end,
    );
  }

  WorkoutSession _toWorkoutSession(HealthDataPoint point) {
    final duration = point.dateTo.difference(point.dateFrom).inMinutes;
    final safeDuration = duration < 0 ? 0 : duration;
    final activity = point.value is WorkoutHealthValue
        ? (point.value as WorkoutHealthValue).workoutActivityName ?? 'Workout'
        : 'Workout';
    final source = _sourceFor(point.sourceName);
    final externalId =
        '$source|${point.dateFrom.toUtc().toIso8601String()}|${point.dateTo.toUtc().toIso8601String()}|$activity';
    final group = _groupFor(activity);
    final tonnage = safeDuration * 5.0;
    return WorkoutSession(
      date: point.dateFrom,
      totalTonnage: tonnage,
      durationMinutes: safeDuration,
      muscleGroupTonnage: {group: tonnage},
      exercises: [
        ExerciseRecord(
          name: activity,
          muscleGroup: group,
          weight: (safeDuration / 10).clamp(0, 150).toDouble(),
          sets: 1,
          reps: safeDuration == 0 ? 1 : safeDuration,
        ),
      ],
      source: source,
      externalId: externalId,
    );
  }

  String _sourceFor(String sourceName) {
    final source = sourceName.toLowerCase();
    if (source.contains('mifit') ||
        source.contains('mi fitness') ||
        source.contains('xiaomi') ||
        source.contains('zepp')) {
      return 'mifit';
    }
    if (source.contains('symmetry')) return 'symmetry_app';
    return 'health_connect';
  }

  String _groupFor(String activity) {
    final value = activity.toLowerCase();
    if (value.contains('run') || value.contains('walk') || value.contains('bike')) {
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
      debugPrint('GoogleFitService: Revoke error: $e');
    }
  }
}

class HealthImportResult {
  final bool isSuccess;
  final String? error;
  final int importedWorkouts;
  final int weightRecords;
  final int sleepSessions;
  final int heartRateRecords;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final DateTime? lastImportedAt;

  const HealthImportResult({
    required this.isSuccess,
    this.error,
    this.importedWorkouts = 0,
    this.weightRecords = 0,
    this.sleepSessions = 0,
    this.heartRateRecords = 0,
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
  final double distanceKm;
  final DateTime lastSync;
  final String? deviceName;
  final String? error;

  GoogleFitDailyData({
    required this.steps,
    required this.activeCalories,
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
