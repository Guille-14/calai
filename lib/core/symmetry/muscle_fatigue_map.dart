import 'dart:math';
import 'symmetry_workout_ledger.dart';

class MuscleFatigueMap {
  static final MuscleFatigueMap _instance = MuscleFatigueMap._internal();
  factory MuscleFatigueMap() => _instance;
  MuscleFatigueMap._internal();

  final Map<String, MuscleState> _muscleStates = {};

  static const Map<String, List<String>> muscleGroups = {
    'pecho': ['pectoral_mayor', 'pectoral_menor', 'serrato_anterior'],
    'espalda': ['dorsal_ancho', 'trapecio', 'romboides', 'erector_spinae'],
    'hombros': ['deltoide_anterior', 'deltoide_medio', 'deltoide_posterior'],
    'biceps': ['biceps_branquial', 'braquial', 'braquiorradial'],
    'triceps': ['triceps_largo', 'triceps_lateral', 'triceps_medial'],
    'antebrazos': ['flexores', 'extensores'],
    'cuadriceps': [
      'recto_femoral',
      'vasto_lateral',
      'vasto_medial',
      'vasto_intermedio'
    ],
    'isquiotibiales': ['biceps_femoral', 'semitendinoso', 'semimembranoso'],
    'gluteos': ['gluteo_mayor', 'gluteo_medio', 'gluteo_menor'],
    'pantorrillas': ['gastrocnemio', 'soleo', 'tibial_anterior'],
    'abdomen': [
      'recto_abdominal',
      'oblicuo_externo',
      'oblicuo_interno',
      'transverso'
    ],
    'core': ['transverso_abdominal', 'multifidus', 'oblicuos'],
  };

  static const Map<String, double> exerciseToMuscleMap = {
    'press banca': 1.0,
    'press inclinado': 0.9,
    'press banca halters': 1.0,
    'aperturas': 0.8,
    'fondos': 0.9,
    'cruces polea': 0.7,
    'dominadas': 0.9,
    'remo con barra': 1.0,
    'remo con mancuerna': 0.8,
    'face pull': 0.6,
    ' Jalón al pecho': 0.9,
    'sentadilla': 1.0,
    'prensa': 0.9,
    'hack': 0.8,
    'extensión de piernas': 0.7,
    'curl de piernas': 0.7,
    'elevación de talones': 0.6,
    'press militar': 1.0,
    'elevación lateral': 0.8,
    'elevación frontal': 0.7,
    'encogimientos': 0.8,
    'curl biceps': 1.0,
    'curl martillo': 0.9,
    'extensión triceps': 0.9,
    'patada triceps': 0.7,
    'crunches': 0.8,
    'plancha': 0.9,
    'mountain climbers': 0.8,
    'rusian twist': 0.7,
  };

  void updateFromWorkout(WorkoutSession session) {
    for (final exercise in session.exercises) {
      final fatigue = exercise.tonnage / 1000;
      final muscleGroup = inferMuscleGroup(exercise.muscleGroup);

      _applyFatigue(muscleGroup, fatigue, session.date);
    }
    _decayOldFatigue();
  }

  /// Normaliza texto: minúsculas, sin espacios sobrantes ni tildes.
  static String _normalize(String value) {
    final lower = value.toLowerCase().trim();
    return lower
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  /// Alias de grupos ya canónicos (incluye las etiquetas que genera el
  /// importador de Health Connect: 'Bíceps Izq', 'Cuádriceps Der', …).
  static const Map<String, String> _aliasGroups = {
    'pecho': 'pecho',
    'espalda': 'espalda',
    'espalda baja': 'espalda',
    'hombros': 'hombros',
    'biceps': 'biceps',
    'biceps izq': 'biceps',
    'biceps der': 'biceps',
    'triceps': 'triceps',
    'antebrazos': 'antebrazos',
    'cuadriceps': 'cuadriceps',
    'cuadriceps izq': 'cuadriceps',
    'cuadriceps der': 'cuadriceps',
    'isquiotibiales': 'isquiotibiales',
    'gluteos': 'gluteos',
    'pantorrillas': 'pantorrillas',
    'pantorrilla izq': 'pantorrillas',
    'pantorrilla der': 'pantorrillas',
    'abdomen': 'abdomen',
    'abdominales': 'abdomen',
    'core': 'core',
    'cardio': 'general',
  };

  /// Ejercicio (por palabras clave) → grupo muscular canónico.
  static const Map<String, List<String>> _exerciseKeywords = {
    'pecho': [
      'press banca',
      'press inclinado',
      'press banca halters',
      'aperturas',
      'cruces polea',
    ],
    'espalda': [
      'dominadas',
      'remo con barra',
      'remo con mancuerna',
      'face pull',
      'jalon al pecho', // cubre 'Jalón al pecho' tras normalizar
    ],
    'hombros': [
      'press militar',
      'elevacion lateral',
      'elevacion frontal',
      'encogimientos',
    ],
    'biceps': ['curl biceps', 'curl martillo'],
    'triceps': ['extension triceps', 'patada triceps'],
    'cuadriceps': [
      'sentadilla',
      'prensa',
      'hack',
      'extension de piernas',
    ],
    'isquiotibiales': ['curl de piernas'],
    'gluteos': [],
    'pantorrillas': ['elevacion de talones'],
    'abdomen': ['crunches', 'plancha', 'mountain climbers', 'rusian twist'],
  };

  static final Map<String, String> _normalizedExerciseGroups =
      _buildExerciseGroups();

  static Map<String, String> _buildExerciseGroups() {
    final out = <String, String>{};
    _exerciseKeywords.forEach((group, exercises) {
      for (final ex in exercises) {
        out[_normalize(ex)] = group;
      }
    });
    return out;
  }

  /// Antes devolvía el nombre del propio ejercicio ('press banca') como clave
  /// de fatiga, pero getHeatMap() lee grupos ('pecho'): el mapa salía siempre 0.
  /// Ahora devuelve SIEMPRE un grupo canónico.
  String inferMuscleGroup(String rawName) {
    final normalized = _normalize(rawName);
    if (normalized.isEmpty) return 'general';

    // 1) Alias directos (grupo ya canónico o etiqueta de Health Connect)
    final alias = _aliasGroups[normalized];
    if (alias != null) return alias;

    // 2) Coincidencia exacta ejercicio → grupo
    final direct = _normalizedExerciseGroups[normalized];
    if (direct != null) return direct;

    // 3) Coincidencia por inclusión (p.ej. "press banca inclinado")
    for (final entry in _normalizedExerciseGroups.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }

    return 'general';
  }

  void _applyFatigue(String muscleGroup, double tonnage, DateTime timestamp) {
    final current = _muscleStates[muscleGroup] ??
        MuscleState(
          lastWorkout: DateTime(2000),
          totalTonnage: 0,
          fatigueLevel: 0,
          recoveryHours: 0,
        );

    _muscleStates[muscleGroup] = MuscleState(
      lastWorkout: timestamp,
      totalTonnage: current.totalTonnage + tonnage,
      fatigueLevel: (current.fatigueLevel + tonnage / 100).clamp(0.0, 100.0),
      recoveryHours: 48,
    );
  }

  void _decayOldFatigue() {
    final now = DateTime.now();
    for (final entry in _muscleStates.entries) {
      final hoursSinceWorkout = now.difference(entry.value.lastWorkout).inHours;
      final decayRate = hoursSinceWorkout / 48;
      final newFatigue =
          (entry.value.fatigueLevel * (1 - decayRate)).clamp(0.0, 100.0);

      _muscleStates[entry.key] = MuscleState(
        lastWorkout: entry.value.lastWorkout,
        totalTonnage: entry.value.totalTonnage,
        fatigueLevel: newFatigue,
        recoveryHours: entry.value.recoveryHours,
      );
    }
  }

  double getFatigueLevel(String muscleGroup) {
    _decayOldFatigue();
    return _muscleStates[muscleGroup]?.fatigueLevel ?? 0;
  }

  bool isRecovered(String muscleGroup) {
    return getFatigueLevel(muscleGroup) < 30;
  }

  bool isFatigued(String muscleGroup) {
    return getFatigueLevel(muscleGroup) > 70;
  }

  List<String> getFatiguedMuscles() {
    return _muscleStates.entries
        .where((e) => e.value.fatigueLevel > 70)
        .map((e) => e.key)
        .toList();
  }

  List<String> getRecoveredMuscles() {
    return _muscleStates.entries
        .where((e) => e.value.fatigueLevel < 30)
        .map((e) => e.key)
        .toList();
  }

  List<String> getRecommendedMuscles() {
    final recovered = getRecoveredMuscles();
    final rarelyUsed =
        muscleGroups.keys.where((g) => !_muscleStates.containsKey(g)).toList();

    final recommended = <String>[];
    recommended.addAll(recovered.take(3));
    recommended.addAll(rarelyUsed.take(2));
    return recommended;
  }

  Map<String, double> getHeatMap() {
    _decayOldFatigue();
    final heatMap = <String, double>{};

    for (final group in muscleGroups.keys) {
      heatMap[group] = getFatigueLevel(group);
    }

    return heatMap;
  }

  double getOverallSymmetryScore() {
    if (_muscleStates.isEmpty) return 100;

    final values = _muscleStates.values.map((s) => s.fatigueLevel).toList();
    if (values.isEmpty) return 100;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            values.length;
    final stdDev = sqrt(variance);

    return (100 - stdDev).clamp(0, 100);
  }

  List<String> getImbalancedMuscles() {
    if (_muscleStates.isEmpty) return [];

    final values = _muscleStates.values.map((s) => s.fatigueLevel).toList();
    if (values.isEmpty) return [];

    final mean = values.reduce((a, b) => a + b) / values.length;

    return _muscleStates.entries
        .where((e) => (e.value.fatigueLevel - mean).abs() > 30)
        .map((e) => e.key)
        .toList();
  }

  Map<String, dynamic> getDetailedAnalysis() {
    return {
      'fatiguedMuscles': getFatiguedMuscles(),
      'recoveredMuscles': getRecoveredMuscles(),
      'recommendedMuscles': getRecommendedMuscles(),
      'imbalancedMuscles': getImbalancedMuscles(),
      'symmetryScore': getOverallSymmetryScore(),
      'heatMap': getHeatMap(),
      'totalMusclesTracked': _muscleStates.length,
    };
  }

  void reset() {
    _muscleStates.clear();
  }
}

class MuscleState {
  final DateTime lastWorkout;
  final double totalTonnage;
  final double fatigueLevel;
  final int recoveryHours;

  const MuscleState({
    required this.lastWorkout,
    required this.totalTonnage,
    required this.fatigueLevel,
    required this.recoveryHours,
  });
}
