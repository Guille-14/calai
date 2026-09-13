

class FoodEntry {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double confidenceScore;
  final String? imageReference;
  final DateTime timestamp;

  FoodEntry({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.confidenceScore,
    this.imageReference,
    required this.timestamp,
  });

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      name: json['name'] as String,
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
      imageReference: json['imageReference'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'confidenceScore': confidenceScore,
      'imageReference': imageReference,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
