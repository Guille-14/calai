/// Resultado validado de una inferencia nutricional.
///
/// Este modelo vive fuera de los servicios HTTP para que la UI, el repositorio
/// y los proveedores de IA compartan el mismo contrato tipado.
class FoodAnalysisResult {
  final List<String> foods;
  final int estimatedCalories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final String confidence;
  final bool isError;
  final String? errorMessage;

  const FoodAnalysisResult({
    required this.foods,
    required this.estimatedCalories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar = 0,
    required this.confidence,
    this.isError = false,
    this.errorMessage,
  });

  const FoodAnalysisResult.error(String message)
      : foods = const [],
        estimatedCalories = 0,
        protein = 0,
        carbs = 0,
        fat = 0,
        sugar = 0,
        confidence = 'low',
        isError = true,
        errorMessage = message;

  /// Margen que se acepta entre las calorías declaradas por la IA y las que
  /// se derivan de sus propios macros antes de recalcular (10%).
  static const double _atwaterTolerance = 0.10;

  /// Factores de Atwater: la energía que aporta cada gramo de macronutriente.
  /// La fibra se contabiliza aparte (2 kcal/g) cuando el proveedor la informa.
  static double atwaterCalories({
    required double protein,
    required double carbs,
    required double fat,
    double fiber = 0,
  }) {
    final total = protein * 4 + carbs * 4 + fat * 9 + fiber * 2;
    return total.isFinite && total > 0 ? total : 0;
  }

  /// Valida tanto el contrato estructurado actual como el formato legacy que
  /// algunos proveedores locales todavía devuelven.
  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    final name = _readString(json['name']);
    final legacyFoods = _readStringList(json['foods']);
    final foods = name.isNotEmpty ? <String>[name] : legacyFoods;
    final macros = _readMap(json['macros']);

    final protein = _readNumber(json['protein'] ?? macros['protein']);
    final carbs = _readNumber(json['carbs'] ?? macros['carbs']);
    final fat = _readNumber(json['fat'] ?? macros['fat']);
    final sugar = _readNumber(json['sugar'] ?? macros['sugar']);
    final rawCalories =
        _readNumber(json['calories'] ?? json['estimatedCalories']);
    if (!rawCalories.isFinite) {
      return const FoodAnalysisResult.error(
          'La IA devolvió un valor de calorías no válido');
    }
    var calories = rawCalories.round();

    // COHERENCIA DE ATWATER.
    //
    // Los modelos de visión estiman las calorías totales por un lado y los
    // gramos de macros por otro, así que a menudo no cuadran: el usuario veía
    // "550 kcal" junto a 30P/40C/10G, que solo suman 370 kcal. Eso destruye la
    // credibilidad de la app al instante.
    //
    // Los macros se estiman mejor que el total (van por ingrediente), así que
    // la fuente de verdad son ellos: P*4 + C*4 + G*9. Se tolera una desviación
    // del 10% porque los factores reales varían (fibra, alcohol, redondeos) y
    // no queremos "corregir" estimaciones que ya eran correctas.
    final macroCalories = atwaterCalories(
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    if (macroCalories > 0) {
      final divergence = (calories - macroCalories).abs();
      final tolerance = macroCalories * _atwaterTolerance;
      if (calories <= 0 || divergence > tolerance) {
        calories = macroCalories.round();
      }
    }

    final validationError = _validate(
      foods: foods,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugar: sugar,
    );
    if (validationError != null) {
      return FoodAnalysisResult.error(validationError);
    }

    return FoodAnalysisResult(
      foods: List.unmodifiable(foods),
      estimatedCalories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugar: sugar,
      confidence: _normalizeConfidence(json['confidence']),
    );
  }

  Map<String, dynamic> toJson() => {
        'foods': foods,
        'estimatedCalories': estimatedCalories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'sugar': sugar,
        'confidence': confidence,
      };

  Map<String, dynamic> toFoodEntryPayload() => {
        'name': foods.join(', '),
        'calories': estimatedCalories.toDouble(),
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'sugar': sugar,
        'confidenceScore': confidence == 'high'
            ? 0.95
            : confidence == 'medium'
                ? 0.75
                : 0.45,
        'timestamp': DateTime.now().toIso8601String(),
      };

  int get totalMacroGrams => (protein + carbs + fat).toInt();

  FoodAnalysisResult copyWith({List<String>? foods}) {
    return FoodAnalysisResult(
      foods: foods ?? this.foods,
      estimatedCalories: estimatedCalories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugar: sugar,
      confidence: confidence,
      isError: isError,
      errorMessage: errorMessage,
    );
  }

  static String? _validate({
    required List<String> foods,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    required double sugar,
  }) {
    if (foods.isEmpty || foods.every((food) => food.trim().isEmpty)) {
      return 'No se pudo identificar comida en la imagen';
    }
    if (calories <= 0 || calories > 10000) {
      return 'La IA devolvió un valor de calorías no válido';
    }
    if ([protein, carbs, fat, sugar].any((value) => !value.isFinite || value < 0 || value > 2000)) {
      return 'La IA devolvió macronutrientes no válidos';
    }
    return null;
  }

  static String _readString(Object? value) => value is String ? value.trim() : '';

  static List<String> _readStringList(Object? value) {
    if (value is! List) return const [];
    final values = List<Object?>.from(value);
    return values
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  static double _readNumber(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static String _normalizeConfidence(Object? value) {
    final confidence = _readString(value).toLowerCase();
    return switch (confidence) {
      'high' => 'high',
      'low' => 'low',
      _ => 'medium',
    };
  }
}
