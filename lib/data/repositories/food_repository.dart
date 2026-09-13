import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_item.dart';
import '../models/product_model.dart';
import '../../models/food_entry.dart';
import '../services/food_service.dart';
import '../services/database_service.dart';
import '../services/external_food_service.dart';
import '../services/image_storage_service.dart';

class FoodRepository {
  final FoodService _foodService;
  final SharedPreferences _prefs;
  final DatabaseService _databaseService;
  final ExternalFoodService _externalFoodService;
  final ImageStorageService _imageStorageService;

  FoodRepository(
    this._foodService,
    this._prefs,
    this._databaseService,
    this._externalFoodService,
    this._imageStorageService,
  );

  Future<List<FoodItem>> getDailyFoodLog(DateTime date) async {
    final String key = 'food_log_${date.toIso8601String().split('T')[0]}';
    final String? storedData = _prefs.getString(key);

    if (storedData != null) {
      final List<dynamic> jsonList = json.decode(storedData);
      return jsonList.map((json) => FoodItem.fromJson(json)).toList();
    }
    return [];
  }

  Future<void> addFoodItem(FoodItem item) async {
    final String key =
        'food_log_${item.timestamp.toIso8601String().split('T')[0]}';
    List<FoodItem> currentLog = await getDailyFoodLog(item.timestamp);
    currentLog.add(item);

    await _prefs.setString(
      key,
      json.encode(currentLog.map((item) => item.toJson()).toList()),
    );
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
    final String key =
        'food_log_${item.timestamp.toIso8601String().split('T')[0]}';
    List<FoodItem> currentLog = await getDailyFoodLog(item.timestamp);
    currentLog.removeWhere((existingItem) => existingItem.id == item.id);

    await _prefs.setString(
      key,
      json.encode(currentLog.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> updateFoodItem(FoodItem item) async {
    final String key =
        'food_log_${item.timestamp.toIso8601String().split('T')[0]}';
    List<FoodItem> currentLog = await getDailyFoodLog(item.timestamp);

    final index =
        currentLog.indexWhere((existingItem) => existingItem.id == item.id);

    if (index == -1) {
      final allKeys = _prefs.getKeys().where((k) => k.startsWith('food_log_'));
      for (final k in allKeys) {
        final data = _prefs.getString(k);
        if (data != null) {
          final List<dynamic> jsonList = json.decode(data);
          final items = jsonList.map((j) => FoodItem.fromJson(j)).toList();
          final existingIndex = items.indexWhere((e) => e.id == item.id);
          if (existingIndex != -1) {
            items[existingIndex] = item;
            await _prefs.setString(
                k, json.encode(items.map((i) => i.toJson()).toList()));
            return;
          }
        }
      }
      return;
    }

    currentLog[index] = item;
    await _prefs.setString(
      key,
      json.encode(currentLog.map((item) => item.toJson()).toList()),
    );
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
