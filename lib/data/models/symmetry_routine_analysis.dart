class SymmetryExtractedExercise {
  final String name;
  final double weight;
  final int sets;
  final int reps;

  const SymmetryExtractedExercise({
    required this.name,
    required this.weight,
    required this.sets,
    required this.reps,
  });

  factory SymmetryExtractedExercise.fromJson(Map<String, dynamic> json) {
    final name = json['name'] is String ? (json['name'] as String).trim() : '';
    final weight = _readNumber(json['weight']);
    final sets = _readInt(json['sets']);
    final reps = _readInt(json['reps']);

    if (name.isEmpty || weight < 0 || sets < 1 || reps < 1) {
      throw const FormatException('Ejercicio de rutina no válido');
    }
    return SymmetryExtractedExercise(
      name: name,
      weight: weight,
      sets: sets,
      reps: reps,
    );
  }

  static double _readNumber(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  static int _readInt(Object? value) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;
}

class SymmetryRoutineAnalysisResult {
  final List<SymmetryExtractedExercise> exercises;
  final bool isError;
  final String? errorMessage;

  const SymmetryRoutineAnalysisResult({
    required this.exercises,
    this.isError = false,
    this.errorMessage,
  });

  const SymmetryRoutineAnalysisResult.error(String message)
      : exercises = const [],
        isError = true,
        errorMessage = message;
}
