import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'health_connect_bridge.dart';

/// Importador de datos desde Health Connect (Hevy)
/// Lee sesiones de ejercicio y los transforma en WorkoutSession
class HealthConnectImporter {
  static final HealthConnectImporter _instance =
      HealthConnectImporter._internal();

  factory HealthConnectImporter() => _instance;
  HealthConnectImporter._internal();

  final Health _health = Health();
  late final HealthConnectBridge _bridge;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Inicializa el importador
  Future<void> initialize(HealthConnectBridge bridge) async {
    if (_isInitialized) return;
    _bridge = bridge;
    _isInitialized = true;
  }

  /// Solicita permisos de acceso a Health Connect
  Future<bool> requestHealthConnectPermissions() async {
    try {
      final permissions = [
        HealthDataType.EXERCISE_TIME,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.STEPS,
        HealthDataType.WORKOUT,
      ];

      // health 13.x: requestAuthorization devuelve la lista de tipos
      // autorizados, no un bool (así lo tenía el código archivado, y por eso
      // no compilaba).
      final granted = await _health.requestAuthorization(permissions);
      return granted.length == permissions.length;
    } catch (e) {
      debugPrint('❌ Error requesting Health Connect permissions: $e');
      return false;
    }
  }

  /// Lee datos de sesiones de ejercicio desde Health Connect
  /// Específicamente optimizado para datos de Hevy
  Future<List<WorkoutSession>> fetchExerciseSessions({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint('🔄 Fetching workout data from Health Connect...');

      // Fetch WORKOUT data (better for Hevy)
      final workoutData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: [HealthDataType.WORKOUT],
      );

      // Fallback: EXERCISE_TIME if no workouts
      if (workoutData.isEmpty) {
        debugPrint('⚠️  No WORKOUT data found, trying EXERCISE_TIME...');
        return await _fetchFromExerciseTime(startDate, endDate);
      }

      debugPrint('✓ Found ${workoutData.length} workouts from Hevy');

      // Fetch energy burned
      final energyData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      return _transformWorkoutData(workoutData, energyData);
    } catch (e) {
      debugPrint('❌ Error fetching exercise sessions: $e');
      return [];
    }
  }

  /// Fallback para leer datos de EXERCISE_TIME
  Future<List<WorkoutSession>> _fetchFromExerciseTime(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final exerciseData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: [HealthDataType.EXERCISE_TIME],
      );

      final energyData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      return _transformToWorkoutSessions(exerciseData, energyData);
    } catch (e) {
      debugPrint('❌ Error fetching from EXERCISE_TIME: $e');
      return [];
    }
  }

  /// Transforma datos WORKOUT (Hevy) a WorkoutSession
  List<WorkoutSession> _transformWorkoutData(
    List<HealthDataPoint> workoutData,
    List<HealthDataPoint> energyData,
  ) {
    final sessions = <WorkoutSession>[];
    final workoutsByDate = <DateTime, List<HealthDataPoint>>{};

    // Agrupar entrenamientos por fecha
    for (final workout in workoutData) {
      final date = DateTime(
        workout.dateFrom.year,
        workout.dateFrom.month,
        workout.dateFrom.day,
      );
      workoutsByDate.putIfAbsent(date, () => []).add(workout);
    }

    // Procesar cada día
    for (final entry in workoutsByDate.entries) {
      final workouts = entry.value;
      final totalTonnage = _calculateTonnageFromWorkouts(workouts);
      final durationMinutes = _calculateDurationFromWorkouts(workouts);
      final muscleGroups = _extractMuscleGroupsFromWorkouts(workouts);

      // Encontrar energía quemada para ese día
      double caloriesBurned = 0;
      for (final energy in energyData) {
        if (energy.dateFrom.year == entry.key.year &&
            energy.dateFrom.month == entry.key.month &&
            energy.dateFrom.day == entry.key.day) {
          if (energy.value is NumericHealthValue) {
            caloriesBurned =
                (energy.value as NumericHealthValue).numericValue.toDouble();
          }
        }
      }

      final exerciseRecords = _transformHevyWorkouts(workouts);

      if (totalTonnage > 0 || exerciseRecords.isNotEmpty) {
        sessions.add(
          WorkoutSession(
            date: entry.key,
            totalTonnage: totalTonnage,
            durationMinutes: durationMinutes,
            muscleGroupTonnage: muscleGroups,
            exercises: exerciseRecords,
          ),
        );

        debugPrint(
            '✓ Added workout: ${entry.key} - Tonnage: $totalTonnage, Duration: $durationMinutes min');
      }
    }

    return sessions;
  }

  /// Calcula tonelaje desde datos de Hevy
  ///
  /// Nota: `WorkoutHealthValue.energyBurned` es un `Duration` en el paquete
  /// `health` (no calorías), así que se estima por minutos de sesión
  /// (min × 5), mismo criterio que el fallback de EXERCISE_TIME.
  double _calculateTonnageFromWorkouts(List<HealthDataPoint> workouts) {
    double tonnage = 0;

    for (final workout in workouts) {
      if (workout.value is WorkoutHealthValue) {
        final minutes =
            workout.dateTo.difference(workout.dateFrom).inMinutes;
        tonnage += minutes * 5;
      }
    }

    return tonnage;
  }

  /// Calcula duración desde datos de Hevy
  int _calculateDurationFromWorkouts(List<HealthDataPoint> workouts) {
    int totalMinutes = 0;

    for (final workout in workouts) {
      final duration = workout.dateTo.difference(workout.dateFrom).inMinutes;
      totalMinutes += duration;
    }

    return totalMinutes;
  }

  /// Extrae grupos musculares desde metadata de Hevy
  Map<String, double> _extractMuscleGroupsFromWorkouts(
    List<HealthDataPoint> workouts,
  ) {
    final muscleGroups = <String, double>{};

    for (final workout in workouts) {
      if (workout.value is WorkoutHealthValue) {
        final workoutValue = workout.value as WorkoutHealthValue;
        final workoutActivityName = workoutValue.workoutActivityName;

        // Mapear nombre de actividad a grupos musculares
        final groups = _mapActivityToMuscleGroups(workoutActivityName);
        // energyBurned es un Duration en health 13.x; se usa la duración
        // de la ventana del punto como proxy de carga.
        final energy =
            workout.dateTo.difference(workout.dateFrom).inMinutes * 0.1;

        for (final group in groups) {
          muscleGroups.update(
            group,
            (value) => value + energy,
            ifAbsent: () => energy,
          );
        }
      }
    }

    return muscleGroups;
  }

  /// Mapea nombres de actividades Hevy a grupos musculares
  List<String> _mapActivityToMuscleGroups(String? activityName) {
    const activityMap = {
      // Pecho
      'Bench Press': ['Pecho', 'Tríceps'],
      'Incline Bench': ['Pecho', 'Hombros'],
      'Dumbbell Press': ['Pecho', 'Tríceps', 'Hombros'],
      'Machine Press': ['Pecho', 'Tríceps'],
      'Push Ups': ['Pecho', 'Tríceps', 'Hombros'],

      // Espalda
      'Deadlift': ['Espalda', 'Espalda Baja', 'Glúteos'],
      'Barbell Row': ['Espalda', 'Bíceps'],
      'Dumbbell Row': ['Espalda', 'Bíceps'],
      'Lat Pulldown': ['Espalda', 'Bíceps'],
      'Pull Ups': ['Espalda', 'Bíceps'],
      'Rows': ['Espalda', 'Bíceps'],
      'Machine Row': ['Espalda', 'Bíceps'],

      // Hombros
      'Shoulder Press': ['Hombros', 'Tríceps'],
      'Lateral Raise': ['Hombros'],
      'Reverse Pec Deck': ['Hombros', 'Espalda'],
      'Overhead Press': ['Hombros', 'Tríceps'],

      // Brazos
      'Barbell Curl': ['Bíceps Izq', 'Bíceps Der'],
      'Dumbbell Curl': ['Bíceps Izq', 'Bíceps Der'],
      'Triceps Dips': ['Tríceps'],
      'Triceps Pushdown': ['Tríceps'],
      'Cable Curl': ['Bíceps Izq', 'Bíceps Der'],

      // Piernas
      'Squat': ['Cuádriceps Izq', 'Cuádriceps Der', 'Glúteos'],
      'Leg Press': ['Cuádriceps Izq', 'Cuádriceps Der', 'Glúteos'],
      'Leg Curl': ['Isquiotibiales'],
      'Leg Extension': ['Cuádriceps Izq', 'Cuádriceps Der'],
      'Lunge': ['Cuádriceps Izq', 'Cuádriceps Der', 'Glúteos'],
      'Calf Raise': ['Pantorrilla Izq', 'Pantorrilla Der'],

      // Abdominales
      'Abs': ['Abdominales'],
      'Crunches': ['Abdominales'],
      'Ab Wheel': ['Abdominales'],
      'Planks': ['Abdominales', 'Espalda Baja'],

      // Cardio/Otros
      'Running': ['Cuádriceps Izq', 'Cuádriceps Der', 'Pantorrilla Izq', 'Pantorrilla Der'],
      'Cycling': ['Cuádriceps Izq', 'Cuádriceps Der', 'Glúteos'],
      'Swimming': ['Pecho', 'Espalda', 'Hombros'],
    };

    if (activityName == null || activityName.isEmpty) {
      return ['general'];
    }

    // Buscar coincidencia exacta o parcial
    for (final key in activityMap.keys) {
      if (activityName.toUpperCase().contains(key.toUpperCase())) {
        return activityMap[key]!;
      }
    }

    return ['general'];
  }

  /// Transforma entrenamientos de Hevy en ExerciseRecord
  List<ExerciseRecord> _transformHevyWorkouts(
    List<HealthDataPoint> workouts,
  ) {
    final records = <ExerciseRecord>[];

    for (final workout in workouts) {
      if (workout.value is WorkoutHealthValue) {
        final workoutValue = workout.value as WorkoutHealthValue;
        final activityName = workoutValue.workoutActivityName ?? 'Workout';
        final duration =
            workout.dateTo.difference(workout.dateFrom).inMinutes;
        // energyBurned es un Duration en health 13.x (no calorías): se usa
        // la duración en minutos como proxy de intensidad.
        final energy = duration.toDouble();

        final muscleGroups = _mapActivityToMuscleGroups(activityName);
        final primaryMuscle =
            muscleGroups.isNotEmpty ? muscleGroups.first : 'general';

        // Estimar peso basado en calorías
        final estimatedWeight = (energy / 10).clamp(0, 150).toDouble();

        records.add(
          ExerciseRecord(
            name: activityName,
            muscleGroup: primaryMuscle,
            weight: estimatedWeight,
            sets: 1,
            reps: duration,
          ),
        );
      }
    }

    return records;
  }

  /// Método auxiliar para transformar datos EXERCISE_TIME (fallback)
  List<WorkoutSession> _transformToWorkoutSessions(
    List<HealthDataPoint> exerciseData,
    List<HealthDataPoint> energyData,
  ) {
    final sessions = <WorkoutSession>[];
    final exercisesByDate = <DateTime, List<HealthDataPoint>>{};

    // Agrupar ejercicios por fecha
    for (final data in exerciseData) {
      final date = DateTime(
        data.dateFrom.year,
        data.dateFrom.month,
        data.dateFrom.day,
      );
      exercisesByDate.putIfAbsent(date, () => []).add(data);
    }

    // Procesar cada día
    for (final entry in exercisesByDate.entries) {
      final exercises = entry.value;
      final totalTonnage = _calculateTonnageFromExercises(exercises);
      final durationMinutes = _calculateDuration(exercises);
      final muscleGroups = _inferMuscleGroups(exercises);

      // Encontrar energía quemada para ese día
      double caloriesBurned = 0;
      for (final energy in energyData) {
        if (energy.dateFrom.year == entry.key.year &&
            energy.dateFrom.month == entry.key.month &&
            energy.dateFrom.day == entry.key.day) {
          if (energy.value is NumericHealthValue) {
            caloriesBurned =
                (energy.value as NumericHealthValue).numericValue.toDouble();
          }
        }
      }

      final exerciseRecords =
          _transformExercises(exercises, caloriesBurned, durationMinutes);

      if (totalTonnage > 0 || exerciseRecords.isNotEmpty) {
        sessions.add(
          WorkoutSession(
            date: entry.key,
            totalTonnage: totalTonnage,
            durationMinutes: durationMinutes,
            muscleGroupTonnage: muscleGroups,
            exercises: exerciseRecords,
          ),
        );
      }
    }

    return sessions;
  }

  /// Calcula tonelaje total desde ejercicios de Health Connect
  double _calculateTonnageFromExercises(List<HealthDataPoint> exercises) {
    double tonnage = 0;

    for (final exercise in exercises) {
      if (exercise.value is NumericHealthValue) {
        final minutes =
            (exercise.value as NumericHealthValue).numericValue.toDouble();
        tonnage += minutes * 5;
      }
    }

    return tonnage;
  }

  /// Calcula duración total del ejercicio
  int _calculateDuration(List<HealthDataPoint> exercises) {
    int totalMinutes = 0;

    for (final exercise in exercises) {
      if (exercise.value is NumericHealthValue) {
        totalMinutes +=
            ((exercise.value as NumericHealthValue).numericValue).toInt();
      }
    }

    return totalMinutes;
  }

  /// Infiere grupos musculares de los ejercicios
  Map<String, double> _inferMuscleGroups(List<HealthDataPoint> exercises) {
    final muscleGroups = <String, double>{};

    for (final exercise in exercises) {
      final source = exercise.sourceName;
      final muscleGroup = _getMuscleGroupFromSource(source);

      if (exercise.value is NumericHealthValue) {
        final tonnage =
            (exercise.value as NumericHealthValue).numericValue * 5;
        muscleGroups.update(
          muscleGroup,
          (value) => value + tonnage,
          ifAbsent: () => tonnage,
        );
      }
    }

    return muscleGroups;
  }

  /// Obtiene el grupo muscular basado en la fuente del ejercicio
  String _getMuscleGroupFromSource(String source) {
    const sourceMap = {
      'Hevy': 'general',
      'Nike Training Club': 'general',
      'Strong': 'general',
      'FitBod': 'general',
    };

    return sourceMap[source] ?? 'general';
  }

  /// Transforma ejercicios individuales en ExerciseRecord
  List<ExerciseRecord> _transformExercises(
    List<HealthDataPoint> exercises,
    double totalCalories,
    int totalDuration,
  ) {
    final records = <ExerciseRecord>[];

    for (final exercise in exercises) {
      if (exercise.value is NumericHealthValue) {
        final minutes =
            (exercise.value as NumericHealthValue).numericValue.toInt();

        final muscleGroup = minutes > 30 ? 'cardio' : 'general';
        final estimatedWeight = (minutes / 10).clamp(0, 100).toDouble();

        records.add(
          ExerciseRecord(
            name: exercise.sourceName,
            muscleGroup: muscleGroup,
            weight: estimatedWeight,
            sets: 1,
            reps: minutes,
          ),
        );
      }
    }

    return records;
  }

  /// Sincroniza datos desde Health Connect al bridge
  Future<int> syncFromHealthConnect({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint('🔄 Starting sync from Health Connect...');
      final sessions = await fetchExerciseSessions(
        startDate: startDate,
        endDate: endDate,
      );

      for (final session in sessions) {
        _bridge.addWorkout(session);
      }

      debugPrint('✓ Synced ${sessions.length} workouts');
      return sessions.length;
    } catch (e) {
      debugPrint('❌ Error syncing from Health Connect: $e');
      return 0;
    }
  }

  /// Obtiene el último entrenamiento desde Health Connect
  Future<WorkoutSession?> getLastWorkout() async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));

      final sessions = await fetchExerciseSessions(
        startDate: startDate,
        endDate: endDate,
      );

      if (sessions.isEmpty) return null;

      sessions.sort((a, b) => b.date.compareTo(a.date));
      return sessions.first;
    } catch (e) {
      debugPrint('❌ Error getting last workout: $e');
      return null;
    }
  }

  /// Verifica si Health Connect está disponible
  Future<bool> isHealthConnectAvailable() async {
    try {
      final hasPermissions = await _health.getAuthorizationStatus(
        types: [HealthDataType.EXERCISE_TIME],
      );
      return hasPermissions.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
