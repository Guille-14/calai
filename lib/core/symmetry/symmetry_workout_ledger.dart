import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'symmetry_rank_system.dart';

class SymmetryWorkoutLedger {
  static final SymmetryWorkoutLedger _instance = SymmetryWorkoutLedger._internal();
  factory SymmetryWorkoutLedger() => _instance;
  SymmetryWorkoutLedger._internal();

  static const String _storageKey = 'symmetry_health_connect_data';

  double _totalTonnage = 0;
  int _totalWorkouts = 0;
  int _totalDurationMinutes = 0;
  DateTime? _lastWorkoutDate;
  Map<String, double> _muscleGroupVolume = {};
  List<WorkoutSession> _recentWorkouts = [];

  double get totalTonnage => _totalTonnage;
  int get totalWorkouts => _totalWorkouts;
  int get totalDurationMinutes => _totalDurationMinutes;
  DateTime? get lastWorkoutDate => _lastWorkoutDate;
  Map<String, double> get muscleGroupVolume => _muscleGroupVolume;
  List<WorkoutSession> get recentWorkouts => _recentWorkouts;

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        _totalTonnage = (data['totalTonnage'] as num?)?.toDouble() ?? 0;
        _totalWorkouts = (data['totalWorkouts'] as num?)?.toInt() ?? 0;
        _totalDurationMinutes =
            (data['totalDurationMinutes'] as num?)?.toInt() ?? 0;
        if (data['lastWorkoutDate'] != null) {
          _lastWorkoutDate = DateTime.parse(data['lastWorkoutDate'] as String);
        }
        _muscleGroupVolume = Map<String, double>.from(
          (data['muscleGroupVolume'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              ) ??
              {},
        );
        _recentWorkouts = (data['recentWorkouts'] as List<dynamic>?)
                ?.map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
      }
    } catch (e) {
      // Start fresh on error
    }
  }

  Future<void> saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'totalTonnage': _totalTonnage,
        'totalWorkouts': _totalWorkouts,
        'totalDurationMinutes': _totalDurationMinutes,
        'lastWorkoutDate': _lastWorkoutDate?.toIso8601String(),
        'muscleGroupVolume': _muscleGroupVolume,
        'recentWorkouts': _recentWorkouts.map((w) => w.toJson()).toList(),
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      // Ignore save errors
    }
  }

  void addWorkout(WorkoutSession session) {
    _totalTonnage += session.totalTonnage;
    _totalWorkouts += 1;
    _totalDurationMinutes += session.durationMinutes;
    _lastWorkoutDate = session.date;

    for (final entry in session.muscleGroupTonnage.entries) {
      _muscleGroupVolume[entry.key] =
          (_muscleGroupVolume[entry.key] ?? 0) + entry.value;
    }

    _recentWorkouts.insert(0, session);
    if (_recentWorkouts.length > 30) {
      _recentWorkouts = _recentWorkouts.sublist(0, 30);
    }

    saveToStorage();
  }

  double getTonnageForMuscleGroup(String muscleGroup) {
    return _muscleGroupVolume[muscleGroup] ?? 0;
  }

  List<String> getMostTrainedMuscles({int limit = 3}) {
    final sorted = _muscleGroupVolume.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  List<String> getLeastTrainedMuscles({int limit = 3}) {
    final sorted = _muscleGroupVolume.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  double calculateVolumeScore() {
    if (_totalWorkouts == 0) return 0;
    final avgTonnagePerWorkout = _totalTonnage / _totalWorkouts;
    return (avgTonnagePerWorkout / 1000).clamp(0, 100);
  }

  void reset() {
    _totalTonnage = 0;
    _totalWorkouts = 0;
    _totalDurationMinutes = 0;
    _lastWorkoutDate = null;
    _muscleGroupVolume.clear();
    _recentWorkouts.clear();
    saveToStorage();
  }
}

class WorkoutSession {
  final DateTime date;
  final double totalTonnage;
  final int durationMinutes;
  final Map<String, double> muscleGroupTonnage;
  final List<ExerciseRecord> exercises;
  final String source;
  final String? externalId;

  const WorkoutSession({
    required this.date,
    required this.totalTonnage,
    required this.durationMinutes,
    required this.muscleGroupTonnage,
    required this.exercises,
    this.source = 'native',
    this.externalId,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'totalTonnage': totalTonnage,
        'durationMinutes': durationMinutes,
        'muscleGroupTonnage': muscleGroupTonnage,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'source': source,
        'externalId': externalId,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      date: DateTime.parse(json['date'] as String),
      totalTonnage: (json['totalTonnage'] as num).toDouble(),
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      muscleGroupTonnage: Map<String, double>.from(
        (json['muscleGroupTonnage'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
      ),
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .map((e) => ExerciseRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      source: json['source']?.toString() ?? 'native',
      externalId: json['externalId']?.toString(),
    );
  }
}

class ExerciseRecord {
  final String name;
  final String muscleGroup;
  final double weight;
  final int sets;
  final int reps;

  const ExerciseRecord({
    required this.name,
    required this.muscleGroup,
    required this.weight,
    required this.sets,
    required this.reps,
  });

  double get tonnage => weight * sets * reps;

  Map<String, dynamic> toJson() => {
        'name': name,
        'muscleGroup': muscleGroup,
        'weight': weight,
        'sets': sets,
        'reps': reps,
      };

  factory ExerciseRecord.fromJson(Map<String, dynamic> json) {
    return ExerciseRecord(
      name: json['name'] as String,
      muscleGroup: json['muscleGroup'] as String,
      weight: (json['weight'] as num).toDouble(),
      sets: (json['sets'] as num).toInt(),
      reps: (json['reps'] as num).toInt(),
    );
  }
}
