import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/security/api_key_store.dart';
import 'ollama_service.dart';
import 'google_ai_service.dart';
import 'image_storage_service.dart';

/// FoodService - Gestiona la lógica de IA (Ollama vs Google Gemini vs OpenRouter)
class FoodService {
  static final OllamaService _ollamaService = OllamaService();
  static final GoogleAiService _googleService = GoogleAiService();
  static final ImageStorageService _imageStorageService = ImageStorageService();
  static bool _isInitialized = false;

  static const String _providerPref = 'ai_provider_mode'; // 'ollama', 'google' o 'openrouter'
  // La clave OpenRouter se guarda vía ApiKeyStore (almacenamiento seguro; la
  // clave legacy 'openrouter_api_key' de SharedPreferences se migra sola).
  static const String _openrouterModelPref = 'openrouter_model';
  static const String _openrouterUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const List<Map<String, String>> availableModels = [];

  static String get model {
    switch (_activeProvider) {
      case 'google':
        return _googleService.selectedModel;
      case 'openrouter':
        return _openrouterModel;
      default:
        return _ollamaService.selectedModel;
    }
  }

  static String? get apiKey {
    switch (_activeProvider) {
      case 'google':
        return _googleService.apiKey;
      case 'openrouter':
        return _openrouterApiKey.isEmpty ? null : _openrouterApiKey;
      default:
        return 'ollama';
    }
  }

  static String _activeProvider = 'ollama';
  static String get activeProvider => _activeProvider;

  static String _openrouterApiKey = '';
  static String _openrouterModel = 'google/gemini-2.5-flash';

  static String _env(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> initFromPrefs() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedProvider = prefs.getString(_providerPref);

      final envKey = _env('OPENROUTER_API_KEY');
      // La clave vive en el almacenamiento seguro (migración automática
      // desde la clave legacy openrouter_api_key de SharedPreferences).
      _openrouterApiKey =
          await ApiKeyStore.get(id: 'openrouter', envFallback: envKey);

      if (savedProvider != null && savedProvider.isNotEmpty) {
        _activeProvider = savedProvider;
      } else {
        // Sin elección explícita del usuario: usar OpenRouter si hay clave
        // disponible (almacenamiento seguro o .env); si no, Ollama.
        _activeProvider = _openrouterApiKey.isNotEmpty ? 'openrouter' : 'ollama';
      }

      final envModel = _env('OPENROUTER_MODEL');
      _openrouterModel = prefs.getString(_openrouterModelPref) ??
          (envModel.isNotEmpty ? envModel : 'google/gemini-2.5-flash');

      await _ollamaService.initialize();
      await _googleService.initialize();

      _isInitialized = true;
      debugPrint('FoodService: Inicializado. Proveedor: $_activeProvider');
    } catch (e) {
      _isInitialized = true;
      debugPrint('FoodService: Error inicializando: $e');
    }
  }

  static Future<void> setProvider(String provider) async {
    _activeProvider = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerPref, provider);
    debugPrint('FoodService: Proveedor cambiado a $provider');
  }

  static void setModel(String m) {
    switch (_activeProvider) {
      case 'google':
        _googleService.updateModel(m);
        break;
      case 'openrouter':
        _openrouterModel = m;
        unawaited(_saveOpenrouterConfig());
        break;
      default:
        _ollamaService.updateModel(m);
    }
  }

  static void setApiKey(String k) {
    switch (_activeProvider) {
      case 'google':
        unawaited(_googleService.updateApiKey(k));
        break;
      case 'openrouter':
        _openrouterApiKey = k.trim();
        unawaited(_saveOpenrouterConfig());
        break;
      default:
        debugPrint(
            'FoodService: el proveedor "$_activeProvider" no usa API key; se ignora la clave recibida');
    }
  }

  static Future<void> _saveOpenrouterConfig() async {
    try {
      await ApiKeyStore.set(id: 'openrouter', value: _openrouterApiKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_openrouterModelPref, _openrouterModel);
    } catch (_) {}
  }

  static Future<void> syncWithAiConfig() async {
    await initFromPrefs();
  }

  /// Llamada genérica a OpenRouter (API compatible con OpenAI).
  static Future<_AiResponse> _openrouterGenerate({
    required String prompt,
    String? imageBase64,
    String? model,
  }) async {
    if (_openrouterApiKey.isEmpty) {
      return _AiResponse.error('API Key de OpenRouter no configurada');
    }
    try {
      final content = <Map<String, dynamic>>[
        {'type': 'text', 'text': prompt},
        if (imageBase64 != null)
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
          },
      ];
      final body = jsonEncode({
        'model': (model != null && model.isNotEmpty) ? model : _openrouterModel,
        'messages': [
          {'role': 'user', 'content': content},
        ],
      });
      final resp = await http
          .post(
            Uri.parse(_openrouterUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_openrouterApiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 90));

      if (resp.statusCode != 200) {
        return _AiResponse.error('OpenRouter ${resp.statusCode}: ${resp.body}');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return _AiResponse.error('OpenRouter: respuesta sin choices');
      }
      final message = (choices.first as Map<String, dynamic>)['message']
          as Map<String, dynamic>?;
      final dynamic raw = message?['content'];
      String text;
      if (raw is String) {
        text = raw;
      } else if (raw is List) {
        text = raw
            .whereType<Map<String, dynamic>>()
            .map((p) => p['text']?.toString() ?? '')
            .join();
      } else {
        text = '';
      }
      if (text.isEmpty) {
        return _AiResponse.error('OpenRouter: respuesta vacía');
      }
      return _AiResponse.ok(text);
    } catch (e) {
      return _AiResponse.error('Error OpenRouter: $e');
    }
  }

  static Future<FoodAnalysisResult> analyzeFoodImageFromBytes(
      Uint8List imageBytes) async {
    if (!_isInitialized) await initFromPrefs();
    try {
      // Una sola normalización antes de elegir proveedor: todos reciben un
      // JPEG de hasta 1024 px y calidad 85, con el mismo coste de cuota.
      final normalizedBytes = await _imageStorageService.prepareForAi(imageBytes);
      final base64Image = await compute(base64Encode, normalizedBytes);
      const prompt = '''Analiza la comida de la imagen. Identifica el plato o
producto y estima la ración visible. Devuelve únicamente el objeto JSON pedido
por el esquema, sin texto adicional. Los valores nutricionales son para la
ración visible, no por 100 g.''';

      if (_activeProvider == 'google') {
        final available = await _googleService.isModelAvailable();
        if (available == false) {
          return FoodAnalysisResult.error(
              'El modelo configurado ya no está disponible, elige uno de la lista actual en Ajustes IA.');
        }
        final resp = await _googleService.generateResponseWithImage(
          prompt: prompt,
          imageBase64: base64Image,
          responseSchema: GoogleAiService.foodResponseSchema,
        );
        if (!resp.isSuccess) {
          return FoodAnalysisResult.error(resp.error ?? 'Error desconocido');
        }
        return _parseFoodResponse(resp.text);
      }

      final String responseText;
      final String? error;
      if (_activeProvider == 'openrouter') {
        final resp = await _openrouterGenerate(
          prompt: prompt,
          imageBase64: base64Image,
        );
        responseText = resp.text;
        error = resp.error;
        if (!resp.isSuccess) return FoodAnalysisResult.error(error ?? 'Error desconocido');
      } else {
        final resp = await _ollamaService.generateResponseWithImage(
          prompt: prompt,
          model: _ollamaService.selectedModel,
          imageBase64: base64Image,
        );
        responseText = resp.text;
        error = resp.error;
        if (!resp.isSuccess) return FoodAnalysisResult.error(error ?? 'Error desconocido');
      }
      return _parseFoodResponse(responseText);
    } catch (e) {
      return FoodAnalysisResult.error('Error: $e');
    }
  }

  static FoodAnalysisResult _parseFoodResponse(String responseText) {
    try {
      final jsonData = _firstJsonObject(responseText);
      if (jsonData != null) return FoodAnalysisResult.fromJson(jsonData);
    } catch (parseErr) {
      debugPrint('FoodService: Error parseando JSON: $parseErr');
    }
    return FoodAnalysisResult.error(
        'La IA respondió pero no se pudo interpretar. Inténtalo de nuevo.');
  }

  /// Extrae el primer objeto JSON completo, incluso si el proveedor lo
  /// envuelve en markdown o añade una frase antes/después.
  static Map<String, dynamic>? _firstJsonObject(String text) {
    for (var start = 0; start < text.length; start++) {
      if (text[start] != '{') continue;
      var depth = 0;
      var inString = false;
      var escaped = false;
      for (var index = start; index < text.length; index++) {
        final char = text[index];
        if (inString) {
          if (escaped) {
            escaped = false;
          } else if (char == '\\') {
            escaped = true;
          } else if (char == '"') {
            inString = false;
          }
          continue;
        }
        if (char == '"') {
          inString = true;
        } else if (char == '{') {
          depth++;
        } else if (char == '}') {
          depth--;
          if (depth == 0) {
            try {
              final decoded = jsonDecode(text.substring(start, index + 1));
              if (decoded is Map<String, dynamic>) return decoded;
            } catch (_) {
              break;
            }
          }
        }
      }
    }
    return null;
  }

  static Future<SymmetryRoutineAnalysisResult> analyzeSymmetryRoutineFromBytes(Uint8List imageBytes, String muscleGroup) async {
    if (!_isInitialized) await initFromPrefs();
    try {
      // La misma compresión se aplica también a las fotos de rutinas.
      final normalizedBytes = await _imageStorageService.prepareForAi(imageBytes);
      final base64Image = await compute(base64Encode, normalizedBytes);
      final prompt = '''
Analiza esta captura de pantalla de mi aplicación de entrenamiento (Symmetry). 
Extrae TODOS los ejercicios realizados.
Responde SOLO con un JSON válido usando estrictamente este formato:
{
  "exercises": [
    {
      "name": "Nombre del Ejercicio",
      "weight": 50,
      "sets": 3,
      "reps": 10
    }
  ]
}
Si un ejercicio no tiene peso, pon 0. Asegúrate de capturar bien todo lo que veas.
''';

      String responseText;
      bool isSuccess;
      String? error;

      if (_activeProvider == 'google') {
        final resp = await _googleService.generateResponseWithImage(
          prompt: prompt,
          model: GoogleAiService.defaultModel,
          imageBase64: base64Image,
        );
        isSuccess = resp.isSuccess;
        responseText = resp.text;
        error = resp.error;
      } else if (_activeProvider == 'openrouter') {
        final resp = await _openrouterGenerate(
          prompt: prompt,
          imageBase64: base64Image,
        );
        isSuccess = resp.isSuccess;
        responseText = resp.text;
        error = resp.error;
      } else {
        final resp = await _ollamaService.generateResponseWithImage(
          prompt: prompt,
          model: _ollamaService.selectedModel,
          imageBase64: base64Image,
        );
        isSuccess = resp.isSuccess;
        responseText = resp.text;
        error = resp.error;
      }

      if (isSuccess) {
        try {
          final jsonData = _firstJsonObject(responseText);
          if (jsonData != null) {
            final List<dynamic> exList = jsonData['exercises'] ?? [];
            final exercises = exList
                .whereType<Map<String, dynamic>>()
                .map(SymmetryExtractedExercise.fromJson)
                .toList();
            return SymmetryRoutineAnalysisResult(exercises: exercises);
          }
        } catch (parseErr) {
          debugPrint('FoodService: Error parseando JSON de rutina: $parseErr');
        }
        return SymmetryRoutineAnalysisResult.error('No se pudo interpretar la rutina desde la imagen.');
      } else {
        return SymmetryRoutineAnalysisResult.error(error ?? 'Error desconocido en la IA.');
      }
    } catch (e) {
      return SymmetryRoutineAnalysisResult.error('Server Error: $e');
    }
  }

  static Future<FoodAnalysisResult> estimateCaloriesFromText(String description) async {
    if (!_isInitialized) await initFromPrefs();
    try {
      final prompt = 'Comida: "$description". Responde SOLO en JSON: {"foods":["nombre"], "estimatedCalories":400, "macros":{"protein":20,"carbs":40,"fat":15}, "confidence":"medium"}';
      
      String responseText;
      bool isSuccess;
      String? error;

      if (_activeProvider == 'google') {
        final resp = await _googleService.generateResponse(prompt: prompt);
        isSuccess = resp.isSuccess;
        responseText = resp.text;
        error = resp.error;
      } else if (_activeProvider == 'openrouter') {
        final resp = await _openrouterGenerate(prompt: prompt);
        isSuccess = resp.isSuccess;
        responseText = resp.text;
        error = resp.error;
      } else {
        final resp = await _ollamaService.generateResponse(
          prompt: prompt,
          model: _ollamaService.selectedModel,
        );
        isSuccess = resp.isSuccess;
        responseText = resp.text;
        error = resp.error;
      }

      if (isSuccess) {
        try {
          final jsonData = _firstJsonObject(responseText);
          if (jsonData != null) {
            return FoodAnalysisResult.fromJson(jsonData);
          }
        } catch (parseErr) {
          debugPrint('Error: $parseErr');
        }
        // No inventar datos: devolver error para no contaminar el registro.
        return FoodAnalysisResult.error(
            'La IA respondió pero no se pudo interpretar. Inténtalo de nuevo.');
      } else {
        return FoodAnalysisResult.error(error ?? 'Error');
      }
    } catch (e) {
      return FoodAnalysisResult.error('Error: $e');
    }
  }

  static Future<String> chatCompletion(
    String userMessage, {
    List<String>? context,
  }) async {
    if (!_isInitialized) await initFromPrefs();
    try {
      final ctxStr = context != null && context.isNotEmpty
          ? 'Historial:\n${context.join("\n")}\n\n'
          : '';
      final prompt = 'Eres asesor nutricional experto. Responde en espanol.\n${ctxStr}Usuario: $userMessage';
      
      if (_activeProvider == 'google') {
        final resp = await _googleService.generateResponse(prompt: prompt);
        return resp.isSuccess ? resp.text : 'Error Google: ${resp.error}';
      } else if (_activeProvider == 'openrouter') {
        final resp = await _openrouterGenerate(prompt: prompt);
        return resp.isSuccess ? resp.text : 'Error OpenRouter: ${resp.error}';
      } else {
        final resp = await _ollamaService.generateResponse(
          prompt: prompt,
          model: _ollamaService.selectedModel,
        );
        return resp.isSuccess ? resp.text : 'Error Ollama: ${resp.error}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<String> generateNutritionSummary(List<Map<String, dynamic>> entries) async {
    if (!_isInitialized) await initFromPrefs();
    try {
      final totalCal = entries.fold<int>(
          0, (sum, e) => sum + ((e['calories'] as num?)?.toInt() ?? 0));
      final prompt = 'Resumen de $totalCal calorias hoy. Feedback breve (2 frases):';
      
      if (_activeProvider == 'google') {
        final resp = await _googleService.generateResponse(prompt: prompt);
        return resp.isSuccess ? resp.text : 'Resumen no disponible';
      } else if (_activeProvider == 'openrouter') {
        final resp = await _openrouterGenerate(prompt: prompt);
        return resp.isSuccess ? resp.text : 'Resumen no disponible';
      } else {
        final resp = await _ollamaService.generateResponse(
          prompt: prompt,
          model: _ollamaService.selectedModel,
        );
        return resp.isSuccess ? resp.text : 'Resumen no disponible';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<bool> testConnection() async {
    if (!_isInitialized) await initFromPrefs();
    try {
      if (_activeProvider == 'google') {
        final resp = await _googleService.generateResponse(prompt: 'ping');
        return resp.isSuccess;
      } else if (_activeProvider == 'openrouter') {
        final resp = await _openrouterGenerate(prompt: 'ping');
        return resp.isSuccess;
      } else {
        return await _ollamaService.isServerAvailable();
      }
    } catch (e) {
      return false;
    }
  }
}

/// Respuesta unificada de los proveedores de IA.
class _AiResponse {
  final bool isSuccess;
  final String text;
  final String? error;

  const _AiResponse._(this.isSuccess, this.text, this.error);

  factory _AiResponse.ok(String text) => _AiResponse._(true, text, null);
  factory _AiResponse.error(String message) =>
      _AiResponse._(false, '', message);
}

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

  FoodAnalysisResult({
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

  factory FoodAnalysisResult.error(String message) {
    return FoodAnalysisResult(
      foods: [],
      estimatedCalories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      sugar: 0,
      confidence: 'low',
      isError: true,
      errorMessage: message,
    );
  }

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString().trim() ?? '';
    final legacyFoods = (json['foods'] as List?)
            ?.map((food) => food.toString().trim())
            .where((food) => food.isNotEmpty)
            .toList() ??
        <String>[];
    final foods = rawName.isNotEmpty ? [rawName] : legacyFoods;
    final macros = json['macros'] as Map<String, dynamic>? ?? {};
    final p = ((json['protein'] ?? macros['protein']) as num?)?.toDouble() ?? 0.0;
    final c = ((json['carbs'] ?? macros['carbs']) as num?)?.toDouble() ?? 0.0;
    final f = ((json['fat'] ?? macros['fat']) as num?)?.toDouble() ?? 0.0;
    final sugar = ((json['sugar'] ?? macros['sugar']) as num?)?.toDouble() ?? 0.0;

    int calories = ((json['calories'] ?? json['estimatedCalories']) as num?)?.toInt() ?? 0;
    if (calories <= 0 && (p > 0 || c > 0 || f > 0)) {
      calories = (p * 4 + c * 4 + f * 9).round();
    }

    if (foods.isEmpty && calories == 0) {
      return FoodAnalysisResult.error('No se pudo identificar comida en la imagen');
    }

    return FoodAnalysisResult(
      foods: foods,
      estimatedCalories: calories,
      protein: p,
      carbs: c,
      fat: f,
      sugar: sugar,
      confidence: json['confidence']?.toString() ?? 'medium',
    );
  }

  Map<String, dynamic> toFoodEntryPayload() {
    return {
      'name': foods.join(', '),
      'calories': estimatedCalories.toDouble(),
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'sugar': sugar,
      'confidenceScore': confidence == 'high' ? 0.95 : (confidence == 'medium' ? 0.75 : 0.45),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  int get totalMacroGrams => (protein + carbs + fat).toInt();
}

class SymmetryExtractedExercise {
  final String name;
  final double weight;
  final int sets;
  final int reps;

  SymmetryExtractedExercise({
    required this.name,
    required this.weight,
    required this.sets,
    required this.reps,
  });

  factory SymmetryExtractedExercise.fromJson(Map<String, dynamic> json) {
    return SymmetryExtractedExercise(
      name: json['name']?.toString() ?? 'Ejercicio Desconocido',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      sets: (json['sets'] as num?)?.toInt() ?? 1,
      reps: (json['reps'] as num?)?.toInt() ?? 10,
    );
  }
}

class SymmetryRoutineAnalysisResult {
  final List<SymmetryExtractedExercise> exercises;
  final bool isError;
  final String? errorMessage;

  SymmetryRoutineAnalysisResult({
    required this.exercises,
    this.isError = false,
    this.errorMessage,
  });

  factory SymmetryRoutineAnalysisResult.error(String message) {
    return SymmetryRoutineAnalysisResult(
      exercises: [],
      isError: true,
      errorMessage: message,
    );
  }
}

