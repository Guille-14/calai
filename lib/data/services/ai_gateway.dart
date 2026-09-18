import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/ai/ai_provider_kind.dart';
import '../../core/security/api_key_store.dart';
import 'ollama_service.dart';
import 'google_ai_service.dart';
import 'image_storage_service.dart';
import '../models/food_analysis_result.dart';
import '../models/symmetry_routine_analysis.dart';

export '../models/food_analysis_result.dart';
export '../models/symmetry_routine_analysis.dart';

/// AiGateway - Gestiona la lógica de IA (Ollama vs Google Gemini vs OpenRouter)
/// Prompt de producción para el análisis de comida.
///
/// Un prompt corto hacía que el modelo tratara el plato como un bloque único y
/// le aplicara raciones estándar de restaurante. Con descomposición por
/// ingredientes, anclajes visuales de tamaño y la regla de grasas ocultas, las
/// estimaciones dejan de quedarse cortas de forma sistemática.
const String _foodAnalysisPrompt = '''
Eres un nutricionista clínico experto en estimación visual volumétrica de
alimentos. Analiza la imagen y estima la ración VISIBLE (no valores por 100 g).

REGLAS OBLIGATORIAS:
1. DESCOMPOSICIÓN: no trates el plato como un bloque único. Sepáralo
   mentalmente en sus componentes (p. ej. pasta cocida, salsa de tomate, carne
   picada, aceite de cocción) y suma sus macros.
2. GRASAS OCULTAS: si el alimento está salteado, frito o tiene brillo
   superficial, asume entre 10 g y 15 g de aceite o mantequilla de cocción. Es
   el error más habitual y el que más sabotea al usuario.
3. REFERENCIAS DE VOLUMEN:
   - Un puño cerrado ≈ 150-200 g de hidratos densos (arroz, pasta, patata).
   - La palma de la mano ≈ 100-150 g de carne o pescado.
   - Una cuchara sopera rasa de aceite = 10 g (~90 kcal).
4. COHERENCIA: las calorías deben cuadrar con los macros que informes
   (proteína x4 + carbohidratos x4 + grasa x9). No los estimes por separado.
5. AMBIGÜEDAD: si la foto está borrosa, demasiado cerca o no distingues los
   ingredientes, usa confidence "low" en vez de inventar una cifra precisa.

Devuelve únicamente el objeto JSON del esquema, sin texto adicional.''';

class AiGateway {
  static final OllamaService _ollamaService = OllamaService();
  static final GoogleAiService _googleService = GoogleAiService();
  static final ImageStorageService _imageStorageService = ImageStorageService();
  static bool _isInitialized = false;
  static Future<void>? _initializationFuture;

  static const String _providerPref = 'ai_provider_mode'; // 'ollama', 'google' o 'openrouter'
  // La clave OpenRouter se guarda vía ApiKeyStore (almacenamiento seguro; la
  // clave legacy 'openrouter_api_key' de SharedPreferences se migra sola).
  static const String _openrouterModelPref = 'openrouter_model';
  static const String _openrouterUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const List<Map<String, String>> availableModels = [];

  static String get model {
    switch (_activeProvider) {
      case AiProviderKind.google:
        return _googleService.selectedModel;
      case AiProviderKind.openRouter:
        return _openrouterModel;
      default:
        return _ollamaService.selectedModel;
    }
  }

  static String? get apiKey {
    switch (_activeProvider) {
      case AiProviderKind.google:
        return _googleService.apiKey;
      case AiProviderKind.openRouter:
        return _openrouterApiKey.isEmpty ? null : _openrouterApiKey;
      default:
        return 'ollama';
    }
  }

  static AiProviderKind _activeProvider = AiProviderKind.ollama;
  static String get activeProvider => _activeProvider.id;
  static AiProviderKind get activeProviderKind => _activeProvider;

  /// Motivo por el que la IA no puede analizar todavía, o `null` si está
  /// lista. De fábrica la app cae en Ollama apuntando a localhost, que en un
  /// móvil no es ningún servidor: sin este aviso el usuario solo ve fallar el
  /// escaneo sin saber por qué.
  static Future<String?> configurationIssue() async {
    await initFromPrefs();
    switch (_activeProvider) {
      case AiProviderKind.openRouter:
        return _openrouterApiKey.isEmpty
            ? 'Falta la API key de OpenRouter.'
            : null;
      case AiProviderKind.google:
        return _googleService.apiKey.isEmpty
            ? 'Falta la API key de Gemini.'
            : null;
      case AiProviderKind.ollama:
        final ollama = OllamaService();
        await ollama.initialize();
        if (await ollama.isServerAvailable()) return null;
        return 'No hay servidor Ollama accesible en ${ollama.baseUrl}.';
    }
  }

  static String _openrouterApiKey = '';
  static String _openrouterModel = 'google/gemini-2.5-flash';

  static String _env(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> initFromPrefs() {
    if (_isInitialized) return Future.value();
    return _initializationFuture ??= _initializeFromPrefs();
  }

  static Future<void> _initializeFromPrefs() async {
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
        _activeProvider = AiProviderKind.fromId(savedProvider);
      } else {
        // Sin elección explícita del usuario: usar OpenRouter si hay clave
        // disponible (almacenamiento seguro o .env); si no, Ollama.
        _activeProvider = _openrouterApiKey.isNotEmpty
            ? AiProviderKind.openRouter
            : AiProviderKind.ollama;
      }

      final envModel = _env('OPENROUTER_MODEL');
      _openrouterModel = prefs.getString(_openrouterModelPref) ??
          (envModel.isNotEmpty ? envModel : 'google/gemini-2.5-flash');

      await _ollamaService.initialize();
      await _googleService.initialize();

      _isInitialized = true;
      debugPrint('AiGateway: Inicializado. Proveedor: ${_activeProvider.id}');
    } catch (e) {
      _isInitialized = true;
      debugPrint('AiGateway: Error inicializando: $e');
    }
  }

  static Future<void> setProvider(String provider) async {
    _activeProvider = AiProviderKind.fromId(provider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerPref, provider);
    debugPrint('AiGateway: Proveedor cambiado a ${_activeProvider.id}');
  }

  static void setModel(String m) {
    switch (_activeProvider) {
      case AiProviderKind.google:
        _googleService.updateModel(m);
        break;
      case AiProviderKind.openRouter:
        _openrouterModel = m;
        unawaited(_saveOpenrouterConfig());
        break;
      default:
        _ollamaService.updateModel(m);
    }
  }

  static void setApiKey(String k) {
    switch (_activeProvider) {
      case AiProviderKind.google:
        unawaited(_googleService.updateApiKey(k));
        break;
      case AiProviderKind.openRouter:
        _openrouterApiKey = k.trim();
        unawaited(_saveOpenrouterConfig());
        break;
      default:
        debugPrint(
            'AiGateway: el proveedor "${_activeProvider.id}" no usa API key; se ignora la clave recibida');
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
  /// Las respuestas de análisis solicitan JSON estructurado y los fallos
  /// transitorios se reintentan sin repetir errores de autenticación.
  static Future<_AiResponse> _openrouterGenerate({
    required String prompt,
    String? imageBase64,
    String? model,
    bool structuredJson = false,
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
      final body = <String, dynamic>{
        'model': (model != null && model.isNotEmpty) ? model : _openrouterModel,
        'messages': [
          {'role': 'user', 'content': content},
        ],
        if (structuredJson) 'response_format': {'type': 'json_object'},
      };
      final resp = await _postOpenRouter(body);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return _AiResponse.error('OpenRouter ${resp.statusCode}: ${resp.body}');
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return _AiResponse.error('OpenRouter: respuesta JSON inválida');
      }
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        return _AiResponse.error('OpenRouter: respuesta sin choices');
      }
      final message = (choices.first as Map)['message'];
      final raw = message is Map ? message['content'] : null;
      final text = raw is String
          ? raw.trim()
          : raw is List
              ? raw
                  .whereType<Map>()
                  .map((part) => part['text']?.toString() ?? '')
                  .join()
                  .trim()
              : '';
      if (text.isEmpty) {
        return _AiResponse.error('OpenRouter: respuesta vacía');
      }
      return _AiResponse.ok(text);
    } catch (e) {
      return _AiResponse.error('Error OpenRouter: $e');
    }
  }

  static Future<http.Response> _postOpenRouter(
      Map<String, dynamic> body) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(_openrouterUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_openrouterApiKey',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 90));
        final transient = response.statusCode == 408 ||
            response.statusCode == 409 ||
            response.statusCode == 429 ||
            response.statusCode >= 500;
        if (!transient || attempt == maxAttempts) return response;
      } catch (_) {
        if (attempt == maxAttempts) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * (1 << (attempt - 1))));
    }
    throw StateError('OpenRouter no devolvió respuesta');
  }

  static Future<FoodAnalysisResult> analyzeFoodImageFromBytes(
      Uint8List imageBytes) async {
    if (!_isInitialized) await initFromPrefs();
    try {
      // Una sola normalización antes de elegir proveedor: todos reciben un
      // JPEG de hasta 1024 px y calidad 85, con el mismo coste de cuota.
      final normalizedBytes = await _imageStorageService.prepareForAi(imageBytes);
      final base64Image = await compute(base64Encode, normalizedBytes);
      const prompt = _foodAnalysisPrompt;

      if (_activeProvider == AiProviderKind.google) {
        // Antes se llamaba a isModelAvailable() antes de CADA foto: una
        // petición HTTP extra para comprobar algo que casi nunca cambia, que
        // duplicaba la latencia y la superficie de fallo. Si el modelo ya no
        // existe, la propia llamada de análisis devuelve 404 y ahí se traduce
        // al mensaje que manda al usuario a Ajustes IA.
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
      if (_activeProvider == AiProviderKind.openRouter) {
        final resp = await _openrouterGenerate(
          prompt: prompt,
          imageBase64: base64Image,
          structuredJson: true,
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
      debugPrint('AiGateway: Error parseando JSON: $parseErr');
    }
    // Sin ver qué contestó el modelo, un "no se pudo interpretar" es
    // imposible de depurar. Se vuelca la respuesta cruda al log y se añade
    // un extracto al mensaje para poder reportar el fallo con datos.
    debugPrint('AiGateway: respuesta no interpretable: $responseText');
    final preview = responseText.trim().replaceAll(RegExp(r'\s+'), ' ');
    final snippet =
        preview.length > 120 ? '${preview.substring(0, 120)}…' : preview;
    return FoodAnalysisResult.error(snippet.isEmpty
        ? 'La IA no devolvió ninguna respuesta. Inténtalo de nuevo.'
        : 'La IA respondió pero no se pudo interpretar. Respondió: "$snippet"');
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

      if (_activeProvider == AiProviderKind.google) {
        final resp = await _googleService.generateResponseWithImage(
          prompt: prompt,
          imageBase64: base64Image,
          responseSchema: GoogleAiService.symmetryRoutineResponseSchema,
        );
        isSuccess = resp.isSuccess;
        responseText = resp.text;
        error = resp.error;
      } else if (_activeProvider == AiProviderKind.openRouter) {
        final resp = await _openrouterGenerate(
          prompt: prompt,
          imageBase64: base64Image,
          structuredJson: true,
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
          debugPrint('AiGateway: Error parseando JSON de rutina: $parseErr');
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
      final prompt = 'Comida: "$description". Devuelve SOLO un JSON válido con este contrato: {"name":"nombre","calories":400,"protein":20,"carbs":40,"fat":15,"sugar":5,"confidence":"medium"}. Estima la ración descrita, no inventes ingredientes ausentes.';
      
      String responseText;
      bool isSuccess;
      String? error;

      if (_activeProvider == AiProviderKind.google) {
        final resp = await _googleService.generateResponse(
          prompt: prompt,
          responseSchema: GoogleAiService.foodResponseSchema,
        );
        isSuccess = resp.isSuccess;
        responseText = resp.text;
        error = resp.error;
      } else if (_activeProvider == AiProviderKind.openRouter) {
        final resp = await _openrouterGenerate(
          prompt: prompt,
          structuredJson: true,
        );
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
      
      if (_activeProvider == AiProviderKind.google) {
        final resp = await _googleService.generateResponse(prompt: prompt);
        return resp.isSuccess ? resp.text : 'Error Google: ${resp.error}';
      } else if (_activeProvider == AiProviderKind.openRouter) {
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
      
      if (_activeProvider == AiProviderKind.google) {
        final resp = await _googleService.generateResponse(prompt: prompt);
        return resp.isSuccess ? resp.text : 'Resumen no disponible';
      } else if (_activeProvider == AiProviderKind.openRouter) {
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
      if (_activeProvider == AiProviderKind.google) {
        final resp = await _googleService.generateResponse(prompt: 'ping');
        return resp.isSuccess;
      } else if (_activeProvider == AiProviderKind.openRouter) {
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
