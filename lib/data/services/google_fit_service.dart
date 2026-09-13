import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

class GoogleFitService {
  GoogleFitService._privateConstructor();

  static final GoogleFitService _instance =
      GoogleFitService._privateConstructor();

  static GoogleFitService get instance => _instance;

  // Instanciación perezosa: evita cargar las clases nativas del plugin
  // health (alpha) durante el arranque si la app no llega a usarlas.
  Health? _healthInstance;
  Health get _health => _healthInstance ??= Health();

  bool _isAuthorized = false;
  DateTime? _lastSyncTime;
  bool _isConfigured = false;

  bool get isAuthorized => _isAuthorized;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isConfigured => _isConfigured;

  final List<HealthDataType> _coreTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
  ];

  Future<bool> configureHealth() async {
    if (!Platform.isAndroid) {
      debugPrint('GoogleFitService: Only Android is supported');
      return false;
    }

    try {
      debugPrint('GoogleFitService: Configuring Health Connect...');
      await _health.configure();
      _isConfigured = true;
      debugPrint('GoogleFitService: Health Connect configured');
      return true;
    } catch (e) {
      debugPrint('GoogleFitService: Configure error: $e');
      return false;
    }
  }

  Future<bool> requestAuthorization() async {
    if (!Platform.isAndroid) {
      debugPrint('GoogleFitService: Only Android is supported');
      return false;
    }

    try {
      if (!_isConfigured) {
        final configured = await configureHealth();
        if (!configured) return false;
      }

      debugPrint(
          'GoogleFitService: Requesting authorization for core types: $_coreTypes');

      final requested = await _health.requestAuthorization(_coreTypes);

      if (requested) {
        _isAuthorized = true;
        debugPrint('GoogleFitService: Authorization granted for core types');
      } else {
        debugPrint('GoogleFitService: Authorization denied');
        return false;
      }

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
      if (!_isConfigured) {
        await configureHealth();
      }

      final hasPermissions = await _health.hasPermissions(_coreTypes);
      _isAuthorized = hasPermissions == true;
      return _isAuthorized;
    } catch (e) {
      debugPrint('GoogleFitService: Check auth error: $e');
      return false;
    }
  }

  Future<bool> isHealthConnectInstalled() async {
    if (!Platform.isAndroid) return false;
    try {
      final installed = await _health.isHealthConnectAvailable();
      debugPrint('GoogleFitService: Health Connect installed: $installed');
      return installed;
    } catch (e) {
      debugPrint('GoogleFitService: Check installed error: $e');
      return false;
    }
  }

  double _extractNumericValue(HealthValue value) {
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    debugPrint(
        'GoogleFitService: Non-numeric value type: ${value.runtimeType}');
    return 0.0;
  }


  Future<GoogleFitDailyData> fetchDailyData() async {
    if (!Platform.isAndroid) return GoogleFitDailyData.error('Solo Android soportado');

    try {
      debugPrint('GoogleFitService: === Fetching daily data ===');

      // Comprueba permisos sin abrir el flujo de autorización: antes se
      // llamaba requestAuthorization() en cada sync (incluido cada
      // pull-to-refresh del Home) disparando el diálogo de permisos.
      bool authorized = await checkAuthorization();
      if (!authorized) {
        authorized = await requestAuthorization();
      }
      if (!authorized) {
        return GoogleFitDailyData.error('No autorizado. Conecta Health Connect.');
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Get steps (Health Connect recommended way)
      int totalSteps = 0;
      try {
        final steps = await _health.getTotalStepsInInterval(startOfDay, now);
        totalSteps = steps ?? 0;
        debugPrint('GoogleFitService: Steps = $totalSteps');
      } catch (e) {
        debugPrint('GoogleFitService: Error en pasos: $e');
      }

      // Fetch total calories (Active + Basal to account for Xiaomi/Zepp Life logic)
      double totalCalories = 0.0;
      try {
        final data = await _health.getHealthDataFromTypes(
          startTime: startOfDay,
          endTime: now,
          types: [
            HealthDataType.ACTIVE_ENERGY_BURNED,
            HealthDataType.BASAL_ENERGY_BURNED,
          ],
        );
        for (final dp in data) {
          totalCalories += _extractNumericValue(dp.value);
        }
        
        // Sometimes TOTAL calories is directly recorded under ACTIVE for some watches but as very large value.
        // It's safe to sum if they accurately separate.
        debugPrint('GoogleFitService: Total Computed Calories = $totalCalories');
      } catch (e) {
        debugPrint('GoogleFitService: Error en calorías: $e');
      }

      // Fetch distance
      double distanceKm = 0.0;
      try {
        final data = await _health.getHealthDataFromTypes(
          startTime: startOfDay,
          endTime: now,
          types: [HealthDataType.DISTANCE_DELTA],
        );
        for (final dp in data) {
          distanceKm += _extractNumericValue(dp.value) / 1000.0;
        }
      } catch (e) {
        debugPrint('GoogleFitService: Error en distancia: $e');
      }

      _lastSyncTime = DateTime.now();

      return GoogleFitDailyData(
        steps: totalSteps,
        activeCalories: totalCalories.toInt(),
        distanceKm: distanceKm,
        lastSync: _lastSyncTime!,
        deviceName: 'Mi Fit / Zepp Life',
      );
    } catch (e) {
      debugPrint('GoogleFitService: General fetch error: $e');
      return GoogleFitDailyData.error('Error de sincronización: $e');
    }
  }


  Future<void> revokeAccess() async {
    try {
      await _health.revokePermissions();
      _isAuthorized = false;
      _lastSyncTime = null;
      debugPrint('GoogleFitService: Access revoked');
    } catch (e) {
      debugPrint('GoogleFitService: Revoke error: $e');
    }
  }
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
      distanceKm: 0.0,
      lastSync: DateTime.now(),
      error: message,
    );
  }

  bool get hasError => error != null;
}
