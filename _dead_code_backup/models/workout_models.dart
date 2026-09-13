
enum SetType { normal, warmup, drop, failure }

extension SetTypeExtension on SetType {
  String get label {
    switch (this) {
      case SetType.normal:
        return '';
      case SetType.warmup:
        return 'W';
      case SetType.drop:
        return 'D';
      case SetType.failure:
        return 'F';
    }
  }

  String get labelFull {
    switch (this) {
      case SetType.normal:
        return 'Normal';
      case SetType.warmup:
        return 'Warm-up';
      case SetType.drop:
        return 'Drop Set';
      case SetType.failure:
        return 'Failure';
    }
  }
}

class WorkoutSession {
  String id;
  DateTime date;
  DateTime? startTime;
  DateTime? endTime;
  int durationMinutes;
  String? routineId;
  String? routineName;
  List<WorkoutExercise> exercises;
  String? notes;

  WorkoutSession({
    String? id,
    required this.date,
    this.startTime,
    this.endTime,
    required this.durationMinutes,
    this.routineId,
    this.routineName,
    required this.exercises,
    this.notes,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  int get totalSets {
    return exercises.fold(
        0, (sum, ex) => sum + ex.sets.where((s) => s.isCompleted).length);
  }

  int get totalVolume {
    return exercises.fold(0, (sum, ex) {
      return sum +
          ex.sets
              .where((s) => s.isCompleted)
              .fold(0, (sSum, s) => sSum + (s.weight * s.reps).toInt());
    });
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'],
      date: DateTime.parse(json['date']),
      startTime:
          json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      durationMinutes: json['durationMinutes'] ?? 0,
      routineId: json['routineId'],
      routineName: json['routineName'],
      exercises: (json['exercises'] as List)
          .map((e) => WorkoutExercise.fromJson(e))
          .toList(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'routineId': routineId,
        'routineName': routineName,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'notes': notes,
      };
}

class WorkoutExercise {
  String name;
  List<ExerciseSet> sets;
  String? notes;
  String? videoUrl; // URL del video tutorial del ejercicio

  WorkoutExercise({
    required this.name,
    required this.sets,
    this.notes,
    this.videoUrl,
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      name: json['name'],
      sets: (json['sets'] as List).map((s) => ExerciseSet.fromJson(s)).toList(),
      notes: json['notes'],
      videoUrl: json['videoUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sets': sets.map((s) => s.toJson()).toList(),
        'notes': notes,
        'videoUrl': videoUrl,
      };
}

class ExerciseSet {
  int setNumber;
  double weight;
  int reps;
  bool isCompleted;
  SetType setType;
  String? previousPerformance;

  ExerciseSet({
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.isCompleted = false,
    this.setType = SetType.normal,
    this.previousPerformance,
  });

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      setNumber: json['setNumber'] ?? 1,
      weight: (json['weight'] ?? 0).toDouble(),
      reps: json['reps'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
      setType: json['setType'] != null
          ? SetType.values.firstWhere(
              (e) => e.toString() == json['setType'],
              orElse: () => SetType.normal,
            )
          : SetType.normal,
      previousPerformance: json['previousPerformance'],
    );
  }

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'weight': weight,
        'reps': reps,
        'isCompleted': isCompleted,
        'setType': setType.toString(),
        'previousPerformance': previousPerformance,
      };
}

class Routine {
  String id;
  String name;
  String? description;
  List<RoutineDay> days;
  bool isPredefined;
  DateTime? createdAt;

  Routine({
    String? id,
    required this.name,
    this.description,
    required this.days,
    this.isPredefined = false,
    this.createdAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      days: (json['days'] as List).map((d) => RoutineDay.fromJson(d)).toList(),
      isPredefined: json['isPredefined'] ?? false,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'days': days.map((d) => d.toJson()).toList(),
        'isPredefined': isPredefined,
        'createdAt': createdAt?.toIso8601String(),
      };
}

class RoutineDay {
  String name;
  List<RoutineExercise> exercises;

  RoutineDay({
    required this.name,
    required this.exercises,
  });

  factory RoutineDay.fromJson(Map<String, dynamic> json) {
    return RoutineDay(
      name: json['name'],
      exercises: (json['exercises'] as List)
          .map((e) => RoutineExercise.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}

class RoutineExercise {
  String name;
  int sets;
  int reps;
  double? restSeconds;

  RoutineExercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.restSeconds,
  });

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    return RoutineExercise(
      name: json['name'],
      sets: json['sets'] ?? 3,
      reps: json['reps'] ?? 10,
      restSeconds: json['restSeconds']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sets': sets,
        'reps': reps,
        'restSeconds': restSeconds,
      };
}

class ExerciseHistoryEntry {
  String exerciseName;
  DateTime date;
  double weight;
  int reps;
  double volume;

  ExerciseHistoryEntry({
    required this.exerciseName,
    required this.date,
    required this.weight,
    required this.reps,
  }) : volume = weight * reps;

  factory ExerciseHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ExerciseHistoryEntry(
      exerciseName: json['exerciseName'],
      date: DateTime.parse(json['date']),
      weight: json['weight'].toDouble(),
      reps: json['reps'],
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'date': date.toIso8601String(),
        'weight': weight,
        'reps': reps,
      };
}
