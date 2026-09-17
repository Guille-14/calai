import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'health_connect_importer.dart';
import 'health_connect_bridge.dart';
import 'symmetry_progression_service.dart';

/// Servicio que maneja sincronizaciones automáticas periódicas con Hevy
class HevyAutoSyncService {
  static final HevyAutoSyncService _instance = HevyAutoSyncService._internal();

  factory HevyAutoSyncService() => _instance;
  HevyAutoSyncService._internal();

  late SharedPreferences _prefs;
  late HealthConnectImporter _importer;
  late HealthConnectBridge _bridge;
  late SymmetryProgressionService _progression;

  bool _isInitialized = false;
  bool _isSyncing = false;

  static const String _lastSyncKey = 'hevy_last_sync_timestamp';
  static const String _syncIntervalKey = 'hevy_sync_interval_hours';
  static const String _autoSyncEnabledKey = 'hevy_auto_sync_enabled';
  static const int _defaultSyncIntervalHours = 24;

  bool get isSyncing => _isSyncing;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _importer = HealthConnectImporter();
    _bridge = HealthConnectBridge();
    _progression = SymmetryProgressionService();

    _isInitialized = true;
  }

  /// Habilita sincronización automática
  Future<void> enableAutoSync({int intervalHours = _defaultSyncIntervalHours}) async {
    await _prefs.setBool(_autoSyncEnabledKey, true);
    await _prefs.setInt(_syncIntervalKey, intervalHours);
    // ignore: avoid_print
    debugPrint('✓ Auto-sync enabled (every $intervalHours hours)');
  }

  /// Deshabilita sincronización automática
  Future<void> disableAutoSync() async {
    await _prefs.setBool(_autoSyncEnabledKey, false);
    // ignore: avoid_print
    debugPrint('✓ Auto-sync disabled');
  }

  /// Verifica si es hora de sincronizar
  bool shouldSync() {
    final isEnabled = _prefs.getBool(_autoSyncEnabledKey) ?? false;
    if (!isEnabled) return false;

    final lastSync = _prefs.getInt(_lastSyncKey) ?? 0;
    final syncInterval = _prefs.getInt(_syncIntervalKey) ?? _defaultSyncIntervalHours;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedHours = (nowMs - lastSync) / (1000 * 60 * 60);

    return elapsedHours >= syncInterval;
  }

  /// Realiza sincronización desde Hevy
  Future<int> performSync() async {
    if (_isSyncing || !_isInitialized) return 0;

    _isSyncing = true;
    int workoutCount = 0;

    try {
      // ignore: avoid_print
      debugPrint('🔄 Starting automatic sync with Hevy...');

      // Inicializar importador
      await _importer.initialize(_bridge);

      // Solicitar permisos (sin bloquear si falla)
      await _importer.requestHealthConnectPermissions();

      // Rango: últimos 30 días
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      // Sincronizar
      workoutCount = await _importer.syncFromHealthConnect(
        startDate: startDate,
        endDate: endDate,
      );

      // Actualizar timestamp
      await _prefs.setInt(
        _lastSyncKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      // Actualizar progresión
      await _progression.initialize();

      // ignore: avoid_print
      debugPrint('✓ Auto-sync completed: $workoutCount workouts imported');
    } catch (e) {
      // ignore: avoid_print
      debugPrint('❌ Auto-sync error: $e');
    } finally {
      _isSyncing = false;
    }

    return workoutCount;
  }

  /// Obtiene información del último sincronización
  Map<String, dynamic> getLastSyncInfo() {
    final lastSyncMs = _prefs.getInt(_lastSyncKey) ?? 0;
    final isEnabled = _prefs.getBool(_autoSyncEnabledKey) ?? false;
    final interval = _prefs.getInt(_syncIntervalKey) ?? _defaultSyncIntervalHours;

    final lastSync = lastSyncMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs)
        : null;

    final now = DateTime.now();
    String? nextSync;
    if (lastSync != null) {
      nextSync = lastSync
          .add(Duration(hours: interval))
          .toIso8601String()
          .split('T')[0];
    }

    return {
      'lastSync': lastSync?.toIso8601String(),
      'nextSync': nextSync,
      'isEnabled': isEnabled,
      'intervalHours': interval,
      'isSyncing': _isSyncing,
      'shouldSync': shouldSync(),
    };
  }

  /// Fuerza una sincronización manual
  Future<int> forceSync() async {
    return await performSync();
  }

  /// Resetea el timestamp de sincronización
  Future<void> resetSyncTimestamp() async {
    await _prefs.remove(_lastSyncKey);
    // ignore: avoid_print
    debugPrint('✓ Sync timestamp reset');
  }
}
