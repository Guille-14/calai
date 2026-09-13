
enum FoodUnit { grams, milliliters }

class Ingredient {
  final String name;
  final int percentage;

  const Ingredient({
    required this.name,
    required this.percentage,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: json['name'] as String? ?? '',
        percentage: json['percentage'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'percentage': percentage,
      };

  Ingredient copyWith({
    String? name,
    int? percentage,
  }) {
    return Ingredient(
      name: name ?? this.name,
      percentage: percentage ?? this.percentage,
    );
  }
}

class FoodItem {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final double quantity;
  final String? imageUrl;
  final DateTime timestamp;
  final List<Ingredient> ingredients;
  final FoodUnit unit;
  final double? confidenceScore;
  final String? aiModel;

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
    required this.quantity,
    this.imageUrl,
    required this.timestamp,
    this.ingredients = const [],
    this.unit = FoodUnit.grams,
    this.confidenceScore,
    this.aiModel,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    var ingredientsList = <Ingredient>[];
    if (json['ingredients'] != null) {
      final list = json['ingredients'] as List;
      for (var item in list) {
        if (item is Map<String, dynamic>) {
          ingredientsList.add(Ingredient.fromJson(item));
        }
      }
    }
    return FoodItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] as String?,
      timestamp: DateTime.parse(
          json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      ingredients: ingredientsList,
      unit: json['unit'] == 'ml' ? FoodUnit.milliliters : FoodUnit.grams,
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble(),
      aiModel: json['aiModel'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'sugar': sugar,
        'quantity': quantity,
        'imageUrl': imageUrl,
        'timestamp': timestamp.toIso8601String(),
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'unit': unit == FoodUnit.milliliters ? 'ml' : 'g',
        'confidenceScore': confidenceScore,
        'aiModel': aiModel,
      };

  FoodItem copyWith({
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? sugar,
    double? quantity,
    String? imageUrl,
    List<Ingredient>? ingredients,
    FoodUnit? unit,
    double? confidenceScore,
    String? aiModel,
  }) {
    return FoodItem(
      id: id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      sugar: sugar ?? this.sugar,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp,
      ingredients: ingredients ?? this.ingredients,
      unit: unit ?? this.unit,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      aiModel: aiModel ?? this.aiModel,
    );
  }

  double get totalIngredientPercentage {
    if (ingredients.isEmpty) return 0;
    return ingredients.fold(0, (sum, ing) => sum + ing.percentage);
  }

  List<Ingredient> get sortedIngredients {
    final sorted = List<Ingredient>.from(ingredients);
    sorted.sort((a, b) => b.percentage.compareTo(a.percentage));
    return sorted;
  }

  String get unitSymbol => unit == FoodUnit.grams ? 'g' : 'ml';
}
