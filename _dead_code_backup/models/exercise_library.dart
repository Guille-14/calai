/// Modelo de ejercicio con información completa, video e instrucciones
class Exercise {
  final String id;
  final String name;
  final String muscleGroup; // chest, back, shoulders, biceps, triceps, forearms, legs, abs, etc
  final String difficulty; // beginner, intermediate, advanced
  final String videoUrl; // URL de YouTube o video embebido
  final String description;
  final List<String> tips; // Consejos para realizar correctamente
  final String equipment; // Dumbbells, Barbell, Machine, Bodyweight, etc
  final int estimatedDurationSeconds; // Duración aproximada en segundos
  final String? thumbnailUrl; // URL de la imagen de portada/foto

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.difficulty,
    required this.videoUrl,
    required this.description,
    required this.tips,
    required this.equipment,
    this.estimatedDurationSeconds = 45,
    this.thumbnailUrl,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'],
      muscleGroup: json['muscleGroup'],
      difficulty: json['difficulty'],
      videoUrl: json['videoUrl'],
      description: json['description'],
      tips: List<String>.from(json['tips'] ?? []),
      equipment: json['equipment'] ?? 'No equipment',
      estimatedDurationSeconds: json['estimatedDurationSeconds'] ?? 45,
      thumbnailUrl: json['thumbnailUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'difficulty': difficulty,
    'videoUrl': videoUrl,
    'description': description,
    'tips': tips,
    'equipment': equipment,
    'estimatedDurationSeconds': estimatedDurationSeconds,
    'thumbnailUrl': thumbnailUrl,
  };
}
