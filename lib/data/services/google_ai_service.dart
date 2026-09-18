import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/security/api_key_store.dart';

/// Respuesta estructurada de Google AI (Gemini).
class GoogleAiResponse {
  final bool isSuccess;
  final String text;
  final String model;
  final Duration duration;
  final String? error;

  GoogleAiResponse({
    required this.isSuccess,
    required this.text,
    required this.model,
    required this.duration,
    this.error,
  });

  factory GoogleAiResponse.success({
    required String text,
    required String model,
    required Duration duration,
  }) {
    return GoogleAiResponse(
      isSuccess: true,
      text: text,
      model: model,
      duration: duration,
      error: null,
    );
  }

  factory GoogleAiResponse.error({
    required String error,
    required String model,
    Duration? duration,
  }) {
    return GoogleAiResponse(
      isSuccess: false,
      text: '',
      model: model,
      duration: duration ?? Duration.zero,
      error: error,
    );
  }
}

/// Servicio para conectar con Google Gemini via API Directa (HTTP).
class GoogleAiService {
  static final GoogleAiService _instance = GoogleAiService._internal();
  factory GoogleAiService() => _instance;
  GoogleAiService._internal();

  static const String _modelPref = 'google_ai_selected_model';

  /// Alias oficial "latest" documentado por Google. No fija una versión que
  /// pueda quedar retirada mientras la app siga instalada.
  static const String defaultModel = 'gemini-flash-latest';
  static const int _maxTransientAttempts = 2;

  String _apiKey = '';
  String _selectedModel = defaultModel;
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  String get selectedModel => _selectedModel;
  String get apiKey => _apiKey;

  /// Schema de la respuesta de comida. Gemini devuelve JSON válido y con la
  /// forma que consume FoodAnalysisResult, sin depender solo del prompt.
  /// Esquema estructurado del análisis de comida.
  ///
  /// Las descripciones no son decorativas: con salida estructurada el modelo
  /// las usa como instrucción por campo. Sin ellas devolvía a veces valores
  /// por 100 g en lugar de por ración, que es el error que más desviaba el
  /// conteo del usuario.
  static Map<String, dynamic> get foodResponseSchema => {
        'type': 'OBJECT',
        'properties': {
          'name': {
            'type': 'STRING',
            'description': 'Nombre descriptivo del plato o producto.',
          },
          'calories': {
            'type': 'NUMBER',
            'description':
                'Calorías de la ración visible. Debe cuadrar con los macros: '
                    'proteína x4 + carbohidratos x4 + grasa x9.',
          },
          'protein': {
            'type': 'NUMBER',
            'description': 'Gramos de proteína de la ración visible.',
          },
          'carbs': {
            'type': 'NUMBER',
            'description': 'Gramos de carbohidratos de la ración visible.',
          },
          'fat': {
            'type': 'NUMBER',
            'description':
                'Gramos de grasa de la ración visible, incluyendo el aceite o '
                    'la mantequilla de cocción aunque no se vean.',
          },
          'sugar': {
            'type': 'NUMBER',
            'description': 'Gramos de azúcar de la ración visible.',
          },
          'confidence': {
            'type': 'STRING',
            'description':
                'Usa "low" si la foto está borrosa o no distingues los '
                    'ingredientes; "high" solo si el plato es inequívoco.',
            'enum': ['low', 'medium', 'high'],
          },
        },
        'required': [
          'name',
          'calories',
          'protein',
          'carbs',
          'fat',
          'sugar',
          'confidence',
        ],
      };

  static Map<String, dynamic> get symmetryRoutineResponseSchema => {
        'type': 'OBJECT',
        'properties': {
          'exercises': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'name': {'type': 'STRING'},
                'weight': {'type': 'NUMBER'},
                'sets': {'type': 'INTEGER'},
                'reps': {'type': 'INTEGER'},
              },
              'required': ['name', 'weight', 'sets', 'reps'],
            },
          },
        },
        'required': ['exercises'],
      };

  Future<void> initialize() =>
      _initializationFuture ??= _initialize();

  Future<void> _initialize() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _apiKey = await ApiKeyStore.get(id: 'gemini');
    _selectedModel = prefs.getString(_modelPref) ?? defaultModel;
    _isInitialized = true;
  }

  Future<void> updateApiKey(String key) async {
    _apiKey = key.trim();
    await ApiKeyStore.set(id: 'gemini', value: _apiKey);
  }

  Future<void> updateModel(String model) async {
    _selectedModel = model.trim().isEmpty ? defaultModel : model.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPref, _selectedModel);
  }

  Future<GoogleAiResponse> generateResponse({
    required String prompt,
    String? model,
    Map<String, dynamic>? responseSchema,
  }) async {
    if (!_isInitialized) await initialize();
    final activeModel = model ?? _selectedModel;
    if (_apiKey.isEmpty) {
      return GoogleAiResponse.error(
        error: 'API Key de Google no configurada',
        model: activeModel,
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      // Mismo motivo que en la ruta con imagen: sin desactivar el
      // razonamiento, los thinking tokens se comen la respuesta.
      final generationConfig = <String, dynamic>{
        'temperature': 0.7,
        'thinkingConfig': {'thinkingBudget': 0},
      };
      if (responseSchema != null) {
        generationConfig['responseMimeType'] = 'application/json';
        generationConfig['responseSchema'] = responseSchema;
      }
      final response = await _postWithTransientRetry(
        _modelUri(activeModel),
        body: {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': generationConfig,
        },
        timeout: const Duration(seconds: 30),
      );
      stopwatch.stop();
      return _responseFromHttp(response, activeModel, stopwatch.elapsed);
    } catch (e) {
      stopwatch.stop();
      return GoogleAiResponse.error(
        error: e.toString(),
        model: activeModel,
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Envía prompt + imagen (base64) a Gemini.
  /// [responseSchema] se usa solo para proveedores/modelos que soportan salida
  /// estructurada; Ollama y OpenRouter mantienen su parser tolerante.
  Future<GoogleAiResponse> generateResponseWithImage({
    required String prompt,
    required String imageBase64,
    String? model,
    Map<String, dynamic>? responseSchema,
  }) async {
    if (!_isInitialized) await initialize();
    final activeModel = model ?? _selectedModel;
    if (_apiKey.isEmpty) {
      return GoogleAiResponse.error(
        error: 'API Key de Google no configurada',
        model: activeModel,
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final generationConfig = <String, dynamic>{
        'temperature': 0.2,
        // Los modelos Flash actuales razonan por defecto y esos "thinking
        // tokens" se descuentan de maxOutputTokens: el modelo se gastaba el
        // presupuesto pensando y el JSON llegaba cortado a media clave
        // ("...,\"protein\":"). Se desactiva el razonamiento (no aporta nada
        // para leer una foto de comida) y se sube el margen de salida.
        'maxOutputTokens': 2048,
        'thinkingConfig': {'thinkingBudget': 0},
      };
      if (responseSchema != null) {
        generationConfig['responseMimeType'] = 'application/json';
        generationConfig['responseSchema'] = responseSchema;
      }

      final response = await _postWithTransientRetry(
        _modelUri(activeModel),
        body: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inlineData': {
                    'mimeType': 'image/jpeg',
                    'data': imageBase64,
                  }
                },
              ]
            }
          ],
          'generationConfig': generationConfig,
        },
        timeout: const Duration(seconds: 60),
      );
      stopwatch.stop();
      return _responseFromHttp(response, activeModel, stopwatch.elapsed);
    } catch (e) {
      stopwatch.stop();
      return GoogleAiResponse.error(
        error: e.toString(),
        model: activeModel,
        duration: stopwatch.elapsed,
      );
    }
  }

  Uri _modelUri(String model) {
    final normalized = model.trim().replaceFirst(RegExp(r'^models/'), '');
    return Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$normalized:generateContent');
  }

  Future<http.Response> _postWithTransientRetry(
    Uri url, {
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    for (var attempt = 1; attempt <= _maxTransientAttempts; attempt++) {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if ((response.statusCode == 429 || response.statusCode == 503) &&
          attempt < _maxTransientAttempts) {
        final delay = Duration(milliseconds: 400 * (1 << (attempt - 1)));
        debugPrint(
            'GoogleAiService: ${response.statusCode}; reintento en ${delay.inMilliseconds}ms');
        await Future<void>.delayed(delay);
        continue;
      }

      // Los modelos antiguos (1.5 y anteriores) no conocen thinkingConfig y
      // responden 400. En ese caso se repite la petición sin ese campo, para
      // no romper a quien tenga elegido uno de esos modelos.
      final config = body['generationConfig'];
      if (response.statusCode == 400 &&
          config is Map &&
          config.containsKey('thinkingConfig') &&
          RegExp('thinking', caseSensitive: false)
              .hasMatch(utf8.decode(response.bodyBytes))) {
        debugPrint(
            'GoogleAiService: el modelo no admite thinkingConfig; reintento sin él');
        final fallbackConfig = Map<String, dynamic>.from(config)
          ..remove('thinkingConfig');
        final fallbackBody = Map<String, dynamic>.from(body)
          ..['generationConfig'] = fallbackConfig;
        return http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': _apiKey,
              },
              body: jsonEncode(fallbackBody),
            )
            .timeout(timeout);
      }

      return response;
    }
    throw StateError('Google API no devolvió respuesta');
  }

  GoogleAiResponse _responseFromHttp(
    http.Response response,
    String model,
    Duration duration,
  ) {
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final candidates = data['candidates'];
      final firstCandidate = candidates is List && candidates.isNotEmpty
          ? candidates.first
          : null;
      final contentValue = firstCandidate is Map
          ? firstCandidate['content']
          : null;
      final parts = contentValue is Map ? contentValue['parts'] : null;
      final content = parts is List
          ? parts
              .map((part) => part is Map ? part['text']?.toString() ?? '' : '')
              .join()
              .trim()
          : '';
      final finishReason = firstCandidate is Map
          ? firstCandidate['finishReason']?.toString()
          : null;

      // Una respuesta truncada llega con contenido (JSON a medias) y
      // finishReason MAX_TOKENS. Devolverla como éxito hacía que el parser
      // fallase después con un "no se pudo interpretar" que no explicaba
      // nada; el motivo real hay que darlo aquí.
      if (finishReason?.trim().toUpperCase() == 'MAX_TOKENS') {
        return GoogleAiResponse.error(
          error: 'La respuesta de Gemini se cortó por longitud. '
              'Prueba otra vez o elige otro modelo en Ajustes IA.',
          model: model,
          duration: duration,
        );
      }

      if (content.isNotEmpty) {
        return GoogleAiResponse.success(
          text: content,
          model: model,
          duration: duration,
        );
      }
      final promptFeedback = data is Map ? data['promptFeedback'] : null;
      final blockReason = promptFeedback is Map
          ? promptFeedback['blockReason']?.toString()
          : null;

      return GoogleAiResponse.error(
        error: _emptyResponseError(
          finishReason: finishReason,
          blockReason: blockReason,
        ),
        model: model,
        duration: duration,
      );
    }

    final body = utf8.decode(response.bodyBytes);
    final isMissingModel = response.statusCode == 404 ||
        (response.statusCode == 400 &&
            RegExp(r'model|not found|not exist|not supported|invalid',
                    caseSensitive: false)
                .hasMatch(body));
    final error = isMissingModel
        ? 'El modelo "$model" no está disponible. Ve a Ajustes IA y elige uno de la lista actual.'
        : 'Error Google API ${response.statusCode}: $body';
    return GoogleAiResponse.error(
      error: error,
      model: model,
      duration: duration,
    );
  }

  String _emptyResponseError({
    String? finishReason,
    String? blockReason,
  }) {
    final block = blockReason?.trim().toUpperCase();
    final finish = finishReason?.trim().toUpperCase();

    if (block != null && block.isNotEmpty && block != 'BLOCK_REASON_UNSPECIFIED') {
      return 'Gemini bloqueó la respuesta por seguridad (motivo: $block).';
    }
    if (finish == 'SAFETY' ||
        finish == 'BLOCKLIST' ||
        finish == 'PROHIBITED_CONTENT' ||
        finish == 'SPII') {
      return 'Gemini bloqueó la respuesta por seguridad (motivo: $finish).';
    }
    if (finish == 'MAX_TOKENS') {
      return 'Gemini cortó la respuesta por límite de tokens.';
    }
    if (finish == 'RECITATION') {
      return 'Gemini bloqueó la respuesta por una coincidencia de contenido (RECITATION).';
    }
    if (finish != null && finish.isNotEmpty) {
      return 'Gemini devolvió una respuesta vacía del modelo (finishReason: $finish).';
    }
    return 'Gemini devolvió una respuesta vacía del modelo.';
  }

  /// Devuelve true/false si la API contestó con catálogo y null si no se
  /// pudo comprobar (sin clave, sin red o respuesta no válida).
  Future<bool?> isModelAvailable({String? model}) async {
    if (!_isInitialized) await initialize();
    if (_apiKey.isEmpty) return null;
    final models = await getAvailableModels();
    if (models.isEmpty) return null;
    final requested = model ?? _selectedModel;
    // Algunos catálogos enumeran solo la versión concreta aunque Google
    // documente el alias latest. Si el catálogo tiene un Flash vigente, el
    // alias oficial sigue siendo una elección válida.
    if (requested == defaultModel) {
      return models.contains(defaultModel) ||
          models.any((name) => name.contains('gemini') && name.contains('flash'));
    }
    return models.contains(requested);
  }

  Future<List<String>> getAvailableModels() async {
    if (!_isInitialized) await initialize();
    if (_apiKey.isEmpty) return [];

    try {
      final response = await http
          .get(
            Uri.parse('https://generativelanguage.googleapis.com/v1beta/models'),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final List<dynamic> models = data['models'] ?? [];
      return models
          .where((m) {
            final name = m['name']?.toString() ?? '';
            final methods = m['supportedGenerationMethods'] as List? ?? [];
            return name.contains('gemini') &&
                methods.contains('generateContent');
          })
          .map((m) => (m['name'] as String).replaceFirst('models/', ''))
          .toList();
    } catch (e) {
      debugPrint('GoogleAiService: Error obteniendo modelos - $e');
      return [];
    }
  }
}
