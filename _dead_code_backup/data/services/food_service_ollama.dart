import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ollama_service.dart';

/// FoodService simplificado - usa SOLO Ollama local
/// Reemplaza multi-provider con configuración Ollama-only
class FoodService {
  static final OllamaService _ollamaService = OllamaService();
  static const String _modelKey = 'ollama_model_food';
  static const String _defaultModel = 'qwen2.5-coder:7b';
  
  static String _selectedModel = _defaultModel;
  static bool _isInitialized = false;

  /// Lista simulada de modelos disponibles (para compatibilidad)
  static const List<Map<String, String>> availableModels = [];

  static String get model => _selectedModel;
  static String? get apiKey => 'ollama'; // Dummy para compatibilidad
  
  static Future<void> initFromPrefs() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModel = prefs.getString(_modelKey);
      
      if (savedModel != null && savedModel.isNotEmpty) {
        _selectedModel = savedModel;
      }
      
      _isInitialized = true;
      debugPrint('FoodService: Inicializado con Ollama - Modelo: $_selectedModel');
    } catch (e) {
      debugPrint('FoodService: Error inicializando: $e');
      _selectedModel = _defaultModel;
      _isInitialized = true;
    }
  }

  static void setModel(String model) {
    _selectedModel = model;
    debugPrint('FoodService: Modelo establecido a: $_selectedModel');
  }

  static void setApiKey(String apiKey) {
    // No-op para Ollama (no necesita API key)
    debugPrint('FoodService: API key ignorada (Ollama local)');
  }

  static Future<void> syncWithAiConfig() async {
    // No-op para Ollama
    debugPrint('FoodService: Sincronización con AiConfig (Ollama local)');
  }

  /// Analiza una imagen de comida y extrae información nutricional
  static Future<FoodAnalysisResult> analyzeFoodImageFromBytes(Uint8List imageBytes) async {
    try {
      // Convertir imagen a base64
      final base64Image = base64Encode(imageBytes);
      
      // Crear prompt descriptivo
      final prompt = '''Analiza esta imagen de comida y proporciona lo siguiente en formato JSON:
{
  "foods": ["lista de alimentos identificados"],
  "estimatedCalories": número,
  "macros": {
    "protein": número,
    "carbs": número,
    "fat": número
  },
  "confidence": "high/medium/low",
  "notes": "observaciones adicionales"
}

Sé preciso y realista en tus estimaciones.''';

      // Usar Ollama para análisis
      final response = await _ollamaService.generateResponse(
        prompt: prompt,
        model: _selectedModel,
      );

      if (response.isSuccess) {
        // Parsear respuesta JSON
        try {
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response.text);
          if (jsonMatch != null) {
            final jsonData = jsonDecode(jsonMatch.group(0)!);
            return FoodAnalysisResult.fromJson(jsonData);
          }
        } catch (e) {
          debugPrint('Error parseando JSON: $e');
        }

        // Fallback: retornar respuesta descriptiva
        return FoodAnalysisResult(
          foods: ['Comida identificada'],
          estimatedCalories: 300,
          protein: 20,
          carbs: 30,
          fat: 10,
          confidence: 'medium',
          rawAnalysis: response.text,
        );
      } else {
        return FoodAnalysisResult.error(response.error ?? 'Error en análisis');
      }
    } catch (e) {
      return FoodAnalysisResult.error('Error: $e');
    }
  }

  /// Estima calorías a partir de una descripción de texto
  static Future<FoodAnalysisResult> estimateCaloriesFromText(String description) async {
    try {
      final prompt = '''Analiza esta descripción de comida y proporciona un análisis nutricional en JSON:
Descripción: $description

Responde en formato JSON:
{
  "foods": ["lista de alimentos"],
  "estimatedCalories": número,
  "macros": {
    "protein": número,
    "carbs": número,
    "fat": número
  },
  "servingSize": "tamaño de la porción",
  "confidence": "high/medium/low"
}''';

      final response = await _ollamaService.generateResponse(
        prompt: prompt,
        model: _selectedModel,
      );

      if (response.isSuccess) {
        try {
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response.text);
          if (jsonMatch != null) {
            final jsonData = jsonDecode(jsonMatch.group(0)!);
            return FoodAnalysisResult.fromJson(jsonData);
          }
        } catch (e) {
          debugPrint('Error parseando JSON: $e');
        }

        return FoodAnalysisResult(
          foods: [description],
          estimatedCalories: 250,
          protein: 15,
          carbs: 25,
          fat: 8,
          confidence: 'medium',
          rawAnalysis: response.text,
        );
      } else {
        return FoodAnalysisResult.error(response.error ?? 'Error en análisis');
      }
    } catch (e) {
      return FoodAnalysisResult.error('Error: $e');
    }
  }

  /// Chat de nutrición
  static Future<String> chatCompletion(
    String userMessage, {
    List<String>? context,
  }) async {
    try {
      final prompt = '''Eres un asesor nutricional experto. Responde de manera útil, concisa y práctico.

${context != null && context.isNotEmpty ? 'Contexto: ${context.join(" ")}' : ''}

Usuario: $userMessage

Responde directamente sin explicaciones previas.''';

      final response = await _ollamaService.generateResponse(
        prompt: prompt,
        model: _selectedModel,
      );

      return response.isSuccess ? response.text : 'Error: ${response.error}';
    } catch (e) {
      return 'Error en la respuesta: $e';
    }
  }

  /// Genera un resumen nutricional
  static Future<String> generateNutritionSummary(List<Map<String, dynamic>> entries) async {
    try {
      final totalCalories = entries.fold<int>(
        0,
        (sum, entry) => sum + (entry['calories'] as int? ?? 0),
      );

      final totalProtein = entries.fold<double>(
        0,
        (sum, entry) => sum + (entry['protein'] as double? ?? 0.0),
      );

      final totalCarbs = entries.fold<double>(
        0,
        (sum, entry) => sum + (entry['carbs'] as double? ?? 0.0),
      );

      final totalFat = entries.fold<double>(
        0,
        (sum, entry) => sum + (entry['fat'] as double? ?? 0.0),
      );

      final prompt = '''Generaun resumen nutricional de este día basado en estos datos:
- Total de calorías: $totalCalories kcal
- Proteína: ${totalProtein.toStringAsFixed(1)}g
- Carbohidratos: ${totalCarbs.toStringAsFixed(1)}g
- Grasas: ${totalFat.toStringAsFixed(1)}g

Proporciona un análisis breve (2-3 oraciones) sobre qué tan bien estuvo la ingesta nutricional del día.''';

      final response = await _ollamaService.generateResponse(
        prompt: prompt,
        model: _selectedModel,
      );

      return response.isSuccess ? response.text : 'Resumen no disponible';
    } catch (e) {
      return 'Error generando resumen: $e';
    }
  }

  /// Test de conexión
  static Future<bool> testConnection() async {
    try {
      final available = await _ollamaService.isServerAvailable();
      debugPrint('FoodService: Ollama disponible: $available');
      return available;
    } catch (e) {
      debugPrint('FoodService: Error en test de conexión: $e');
      return false;
    }
  }
}

/// Modelo de resultado de análisis de comida
class FoodAnalysisResult {
  final List<String> foods;
  final int estimatedCalories;
  final double protein;
  final double carbs;
  final double fat;
  final String confidence;
  final String? rawAnalysis;
  final bool isError;
  final String? errorMessage;

  FoodAnalysisResult({
    required this.foods,
    required this.estimatedCalories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.confidence,
    this.rawAnalysis,
    this.isError = false,
    this.errorMessage,
  });

  factory FoodAnalysisResult.error(String message) {
    return FoodAnalysisResult(
      foods: [],
      estimatedCalories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      confidence: 'low',
      isError: true,
      errorMessage: message,
    );
  }

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    final macros = json['macros'] as Map<String, dynamic>? ?? {};
    
    return FoodAnalysisResult(
      foods: List<String>.from(json['foods'] ?? []),
      estimatedCalories: json['estimatedCalories'] ?? 300,
      protein: (macros['protein'] ?? 15).toDouble(),
      carbs: (macros['carbs'] ?? 30).toDouble(),
      fat: (macros['fat'] ?? 10).toDouble(),
      confidence: json['confidence'] ?? 'medium',
      rawAnalysis: json.toString(),
    );
  }

  int get totalMacroGrams => (protein + carbs + fat).toInt();
}
