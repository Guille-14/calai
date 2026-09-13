import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/workout_models.dart';
import 'strength_ranks_service.dart';

class WorkoutStorageService {
  static const String _sessionsKey = 'workout_sessions';
  static const String _routinesKey = 'workout_routines';

  Future<List<WorkoutSession>> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_sessionsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((e) => WorkoutSession.fromJson(e)).toList();
  }

  Future<void> _saveSessions(List<WorkoutSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _sessionsKey, jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }

  Future<void> saveSession(WorkoutSession session) async {
    final sessions = await _loadSessions();
    sessions.add(session);
    sessions.sort((a, b) => b.date.compareTo(a.date));
    await _saveSessions(sessions);

    // Automatically update muscle ranks
    final ranksService = StrengthRanksService();
    await ranksService.updateRanksFromWorkout(session);
  }

  Future<List<WorkoutSession>> getAllSessions() async {
    return await _loadSessions();
  }

  Future<List<WorkoutSession>> getSessionsByExercise(
      String exerciseName) async {
    final sessions = await _loadSessions();
    return sessions
        .where((s) => s.exercises.any((e) => e.name == exerciseName))
        .toList();
  }

  Future<Map<String, dynamic>> getExerciseStats(String exerciseName) async {
    final sessions = await _loadSessions();
    double maxWeight = 0;
    int maxReps = 0;
    double maxVolume = 0;
    List<Map<String, dynamic>> history = [];

    for (final session in sessions) {
      for (final exercise in session.exercises) {
        if (exercise.name == exerciseName) {
          for (final set in exercise.sets.where((s) => s.isCompleted)) {
            if (set.weight > maxWeight) maxWeight = set.weight;
            if (set.reps > maxReps) maxReps = set.reps;
            final volume = set.weight * set.reps;
            if (volume > maxVolume) maxVolume = volume;
            history.add({
              'date': session.date.toIso8601String(),
              'weight': set.weight,
              'reps': set.reps,
              'volume': volume,
            });
          }
        }
      }
    }

    return {
      'maxWeight': maxWeight,
      'maxReps': maxReps,
      'maxVolume': maxVolume,
      'history': history,
    };
  }

  Future<String> getPreviousPerformance(
      String exerciseName, int setNumber) async {
    final sessions = await _loadSessions();
    for (int i = sessions.length - 1; i >= 0; i--) {
      final session = sessions[i];
      for (final exercise in session.exercises) {
        if (exercise.name == exerciseName) {
          for (final set in exercise.sets) {
            if (set.setNumber == setNumber && set.isCompleted) {
              return '${set.weight.toStringAsFixed(1)}kg x ${set.reps}';
            }
          }
        }
      }
    }
    return '-';
  }

  Future<List<String>> getAllExerciseNames() async {
    final sessions = await _loadSessions();
    final Set<String> names = {};
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        if (exercise.name.isNotEmpty) names.add(exercise.name);
      }
    }
    return names.toList()..sort();
  }

  Future<List<Routine>> _loadRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_routinesKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((e) => Routine.fromJson(e)).toList();
  }

  Future<void> _saveRoutines(List<Routine> routines) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _routinesKey, jsonEncode(routines.map((r) => r.toJson()).toList()));
  }

  Future<List<Routine>> getAllRoutines() async {
    return await _loadRoutines();
  }

  Future<void> saveRoutine(Routine routine) async {
    final routines = await _loadRoutines();
    final index = routines.indexWhere((r) => r.id == routine.id);
    if (index != -1) {
      routines[index] = routine;
    } else {
      routines.add(routine);
    }
    await _saveRoutines(routines);
  }

  Future<void> deleteRoutine(String routineId) async {
    final routines = await _loadRoutines();
    routines.removeWhere((r) => r.id == routineId);
    await _saveRoutines(routines);
  }

  Future<void> deleteSession(String sessionId) async {
    final sessions = await _loadSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await _saveSessions(sessions);
  }
}
