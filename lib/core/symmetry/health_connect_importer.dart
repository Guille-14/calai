import 'package:flutter/foundation.dart';

import '../../data/services/google_fit_service.dart';
import 'symmetry_workout_ledger.dart';

/// Compatibilidad con la integración histórica de Hevy.
///
/// La implementación real vive en GoogleFitService, que es el único bridge
/// que habla con el plugin health/Health Connect. Esta fachada mantiene la API
/// que usa la pantalla antigua de sync sin volver a llamar "Health Connect" a
/// un registro local.
class HealthConnectImporter {
  static final HealthConnectImporter _instance =
      HealthConnectImporter._internal();
  factory HealthConnectImporter() => _instance;
  HealthConnectImporter._internal();

  final GoogleFitService _service = GoogleFitService.instance;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize(SymmetryWorkoutLedger bridge) async {
    _isInitialized = true;
  }

  Future<bool> requestHealthConnectPermissions() async {
    return _service.requestAuthorization();
  }

  Future<List<WorkoutSession>> fetchExerciseSessions({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final result = await _service.importFullHistory(since: startDate);
      if (!result.isSuccess) return [];
      return _service.lastImportedSessions
          .where((session) =>
              !session.date.isBefore(startDate) &&
              !session.date.isAfter(endDate))
          .toList();
    } catch (e) {
      debugPrint('HealthConnectImporter: error leyendo sesiones: $e');
      return [];
    }
  }

  Future<int> syncFromHealthConnect({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final result = await _service.importFullHistory(since: startDate);
      return result.isSuccess ? result.importedWorkouts : 0;
    } catch (e) {
      debugPrint('HealthConnectImporter: error sincronizando: $e');
      return 0;
    }
  }

  Future<WorkoutSession?> getLastWorkout() async {
    if (_service.lastImportedSessions.isEmpty) return null;
    final sessions = [..._service.lastImportedSessions]
      ..sort((a, b) => b.date.compareTo(a.date));
    return sessions.first;
  }

  Future<bool> isHealthConnectAvailable() =>
      _service.isHealthConnectInstalled();
}
