import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_item.dart';
import '../models/product_model.dart';
import '../../models/food_entry.dart';
import '../services/food_service.dart';
import '../services/database_service.dart';
import '../services/external_food_service.dart';
import '../services/image_storage_service.dart';

class FoodRepository {
  final SharedPreferences _prefs;
  final DatabaseService _databaseService;
  final ExternalFoodService _externalFoodService;
  final ImageStorageService _imageStorageService;

  FoodRepository(
    this._prefs,
    this._databaseService,
    this._externalFoodService,
    this._imageStorageService,
  );

  // ------------------------------------------------------------------
  // Registro diario de comidas en SQLite (tabla food_entries).
  //
  // Antes todo vivía en SharedPreferences como JSON por día
  // (food_log_YYYY-MM-DD): nada indexado, bucles de ~30 claves por
  // pantalla y sin forma de cruzar los datos con los de entrenamiento.
  // Las firmas públicas se mantienen para no romper a FoodLogCubit ni a
  // progress_screen.
  // ------------------------------------------------------------------

  static Map<String, dynamic> _foodItemToRow(FoodItem item) => {
        'id': item.id,
        'name': item.name,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
        'sugar': item.sugar,
        'quantity': item.quantity,
        'unit': item.unit == FoodUnit.milliliters ? 'ml' : 'g',
        'timestamp': item.timestamp.millisecondsSinceEpoch,
        'image_url': item.imageUrl,
        'confidence_score': item.confidenceScore,
        'ai_model': item.aiModel,
        'ingredients':
            jsonEncode(item.ingredients.map((i) => i.toJson()).toList()),
      };

  static FoodItem _rowToFoodItem(Map<String, dynamic> row) {
    List<Ingredient> ingredients = const [];
    final rawIngredients = row['ingredients'] as String?;
    if (rawIngredients != null && rawIngredients.isNotEmpty) {
      try {
        ingredients = (jsonDecode(rawIngredients) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((e) => Ingredient.fromJson(e))
            .toList();
      } catch (_) {
        // JSON de ingredientes corrupto: se conserva el resto del registro
      }
    }
    return FoodItem(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      calories: (row['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (row['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (row['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (row['fat'] as num?)?.toDouble() ?? 0.0,
      sugar: (row['sugar'] as num?)?.toDouble() ?? 0.0,
      quantity: (row['quantity'] as num?)?.toDouble() ?? 0.0,
      imageUrl: row['image_url'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      ingredients: ingredients,
      unit: (row['unit'] as String? ?? 'g') == 'ml'
          ? FoodUnit.milliliters
          : FoodUnit.grams,
      confidenceScore: (row['confidence_score'] as num?)?.toDouble(),
      aiModel: row['ai_model'] as String?,
    );
  }

  Future<List<FoodItem>> getDailyFoodLog(DateTime date) async {
    final rows = await _databaseService.getFoodEntriesBetween(date, date);
    return rows.map(_rowToFoodItem).toList();
  }

  /// Comidas de un rango de fechas (para Progreso: mes visible, semana, etc.).
  Future<List<FoodItem>> getFoodLogForRange(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final rows =
        await _databaseService.getFoodEntriesBetween(startInclusive, endInclusive);
    return rows.map(_rowToFoodItem).toList();
  }

  /// Últimas [limit] comidas registradas, cualquiera que sea su fecha.
  Future<List<FoodItem>> getRecentFoodEntries(int limit) async {
    final rows = await _databaseService.getRecentFoodEntries(limit);
    return rows.map(_rowToFoodItem).toList();
  }

  Future<void> addFoodItem(FoodItem item) async {
    await _databaseService.insertFoodEntry(_foodItemToRow(item));
  }

  /// Convierte la confianza textual de la IA ('high'/'medium'/'low' o numérica)
  /// en un score 0..1. Antes `double.tryParse('high')` devolvía siempre null
  /// y toda comida se guardaba con 0.5.
  double _confidenceToScore(String confidence) {
    final asNumber = double.tryParse(confidence);
    if (asNumber != null) return asNumber.clamp(0.0, 1.0);
    switch (confidence.toLowerCase()) {
      case 'high':
        return 0.95;
      case 'medium':
        return 0.75;
      case 'low':
        return 0.45;
      default:
        return 0.5;
    }
  }

  Future<Either<String, FoodItem>> detectFoodFromImage(
      Uint8List imageBytes) async {
    try {
      final result = await FoodService.analyzeFoodImageFromBytes(imageBytes);

      if (result.isError) {
        return Left(result.errorMessage ?? 'Error en el análisis');
      }

      // Crear FoodEntry desde FoodAnalysisResult
      final foodEntry = FoodEntry(
        name: result.foods.isNotEmpty ? result.foods.first : 'Comida',
        calories: result.estimatedCalories.toDouble(),
        protein: result.protein,
        carbs: result.carbs,
        fat: result.fat,
        confidenceScore: _confidenceToScore(result.confidence),
        timestamp: DateTime.now(),
      );

      final String foodId = DateTime.now().millisecondsSinceEpoch.toString();
      final String imagePath =
          await _imageStorageService.saveFoodImage(imageBytes, foodId);

      final unit = _inferUnitFromFoodName(foodEntry.name);

      final List<Ingredient> ingredients = []; // FoodEntry no tiene ingredients detallados

      return Right(FoodItem(
        id: foodId,
        name: foodEntry.name,
        calories: foodEntry.calories,
        protein: foodEntry.protein,
        carbs: foodEntry.carbs,
        fat: foodEntry.fat,
        sugar: 0,
        quantity: 100,
        timestamp: DateTime.now(),
        ingredients: ingredients,
        imageUrl: imagePath,
        unit: unit,
        confidenceScore: foodEntry.confidenceScore,
      ));
    } catch (e) {
      // No inventar datos: si el análisis falla, propagamos el error.
      return Left('Error analizando la imagen: $e');
    }
  }

  Future<Either<String, FoodItem>> detectFoodFromDescription(
      String description) async {
    try {
      final result = await FoodService.estimateCaloriesFromText(description);

      if (result.isError) {
        return Left(result.errorMessage ?? 'Error en el análisis');
      }

      // Crear FoodEntry desde FoodAnalysisResult
      final foodEntry = FoodEntry(
        name: result.foods.isNotEmpty ? result.foods.first : description,
        calories: result.estimatedCalories.toDouble(),
        protein: result.protein,
        carbs: result.carbs,
        fat: result.fat,
        confidenceScore: _confidenceToScore(result.confidence),
        timestamp: DateTime.now(),
      );

      final String foodId = DateTime.now().millisecondsSinceEpoch.toString();
      final unit = _inferUnitFromFoodName(foodEntry.name);

      final List<Ingredient> ingredients = []; // FoodEntry no tiene ingredients detallados

      return Right(FoodItem(
        id: foodId,
        name: foodEntry.name,
        calories: foodEntry.calories,
        protein: foodEntry.protein,
        carbs: foodEntry.carbs,
        fat: foodEntry.fat,
        sugar: 0,
        quantity: 100,
        timestamp: DateTime.now(),
        ingredients: ingredients,
        imageUrl: null,
        unit: unit,
        confidenceScore: foodEntry.confidenceScore,
      ));
    } catch (e) {
      return Left('Error: $e');
    }
  }

  Future<void> deleteFoodItem(FoodItem item) async {
    await _databaseService.deleteFoodEntry(item.id);
  }

  /// Upsert por id: si la comida existe se reemplaza (puede moverse de día
  /// si el timestamp cambió); si no existe se inserta.
  Future<void> updateFoodItem(FoodItem item) async {
    await _databaseService.insertFoodEntry(_foodItemToRow(item));
  }

  // ------------------------------------------------------------------
  // Migración one-shot: SharedPreferences (food_log_YYYY-MM-DD) -> SQLite
  // ------------------------------------------------------------------

  static const String _migratedFoodLogKey = 'migrated_food_log_v1';

  /// Importa a food_entries todas las claves food_log_* de SharedPreferences.
  ///
  /// Reglas (no debe perderse ni una comida ya registrada):
  /// - Si la tabla ya tiene datos, se da por migrada y solo se marca.
  /// - La importación va en una sola transacción; las claves de
  ///   SharedPreferences solo se borran si su importación fue exitosa.
  /// - La marca migrated_food_log_v1 se escribe AL FINAL; si algo falla,
  ///   se reintenta en el siguiente arranque.
  Future<void> migrateFoodLogFromPrefs() async {
    if (_prefs.getBool(_migratedFoodLogKey) ?? false) return;

    final existing = await _databaseService.countFoodEntries();
    if (existing > 0) {
      await _prefs.setBool(_migratedFoodLogKey, true);
      return;
    }

    final keys =
        _prefs.getKeys().where((k) => k.startsWith('food_log_')).toList();
    if (keys.isEmpty) {
      await _prefs.setBool(_migratedFoodLogKey, true);
      return;
    }

    final rows = <Map<String, dynamic>>[];
    final migratedKeys = <String>[];
    for (final key in keys) {
      final data = _prefs.getString(key);
      if (data == null) continue;
      try {
        final List<dynamic> jsonList = json.decode(data);
        for (final j in jsonList) {
          final item = FoodItem.fromJson(j as Map<String, dynamic>);
          rows.add(_foodItemToRow(item));
        }
        migratedKeys.add(key);
      } catch (e) {
        // Una clave corrupta no aborta la migración: se queda en prefs y
        // se reporta para no borrar datos ilegibles.
        debugPrint('migrateFoodLogFromPrefs: no se pudo leer $key: $e');
      }
    }

    if (rows.isNotEmpty) {
      await _databaseService.insertFoodEntries(rows);
    }
    if (migratedKeys.isNotEmpty) {
      for (final key in migratedKeys) {
        await _prefs.remove(key);
      }
    }
    await _prefs.setBool(_migratedFoodLogKey, true);
    debugPrint(
        'migrateFoodLogFromPrefs: ${rows.length} comidas migradas a SQLite');
  }

  Future<Either<String, List<ProductModel>>> getFoodData(String query) async {
    if (query.isEmpty) {
      return const Left('La búsqueda no puede estar vacía');
    }

    final isBarcode = RegExp(r'^\d{8,14}$').hasMatch(query);

    if (isBarcode) {
      final cachedProduct = await _databaseService.getProductByBarcode(query);
      if (cachedProduct != null) {
        return Right([cachedProduct]);
      }

      final apiProduct = await _externalFoodService.getProductByBarcode(query);
      if (apiProduct != null) {
        await _databaseService.saveProduct(apiProduct);
        return Right([apiProduct]);
      }

      return const Left('Producto no encontrado');
    }

    final localResults = await _databaseService.searchProducts(query);
    if (localResults.isNotEmpty) {
      return Right(localResults);
    }

    final apiResults = await _externalFoodService.searchProducts(query);
    if (apiResults.isNotEmpty) {
      for (final product in apiResults) {
        await _databaseService.saveProduct(product);
      }
      return Right(apiResults);
    }

    final aiResult = await _getAiFoodData(query);
    if (aiResult != null) {
      await _databaseService.saveProduct(aiResult);
      return Right([aiResult]);
    }

    return const Left('No se encontró información nutricional');
  }

  Future<ProductModel?> _getAiFoodData(String query) async {
    try {
      final result = await FoodService.estimateCaloriesFromText(query);

      if (result.isError) {
        return null;
      }

      return ProductModel.create(
        name: result.foods.isNotEmpty ? result.foods.first : query,
        calories: result.estimatedCalories.toDouble(),
        proteins: result.protein,
        carbs: result.carbs,
        fats: result.fat,
        sugar: 0,
        fiber: 0,
        category: 'IA',
      );
    } catch (e) {
      return null;
    }
  }

  Future<String?> generateDailySummary() async {
    try {
      final today = DateTime.now();
      final meals = await getDailyFoodLog(today);

      if (meals.isEmpty) {
        return null;
      }

      final entries = meals
          .map((m) => {
                'name': m.name,
                'calories': m.calories,
                'protein': m.protein,
                'carbs': m.carbs,
                'fat': m.fat,
              })
          .toList();

      return await FoodService.generateNutritionSummary(entries);
    } catch (e) {
      return null;
    }
  }

  FoodUnit _inferUnitFromFoodName(String foodName) {
    final lowerName = foodName.toLowerCase();

    final liquidKeywords = [
      'agua',
      'water',
      'jugo',
      'juice',
      'refresco',
      'soda',
      'cola',
      'leche',
      'milk',
      'cerveza',
      'beer',
      'vino',
      'wine',
      'licor',
      'cafe',
      'coffee',
      'te',
      'tea',
      'batido',
      'smoothie',
      'sopa',
      'soup',
      'caldo',
      'broth',
      'aceite',
      'oil',
      'salsa',
      'sauce',
      'miel',
      'honey',
    ];

    for (final keyword in liquidKeywords) {
      if (lowerName.contains(keyword)) {
        return FoodUnit.milliliters;
      }
    }

    return FoodUnit.grams;
  }
}
