import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Respuesta estructurada de Google AI (Gemini)
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

/// Servicio para conectar con Google Gemini via API Directa (HTTP)
class GoogleAiService {
  static final GoogleAiService _instance = GoogleAiService._internal();
  factory GoogleAiService() => _instance;
  GoogleAiService._internal();

  static const String _apiKeyPref = 'google_ai_api_key';
  static const String _modelPref = 'google_ai_selected_model';
  static const String _defaultModel = 'gemini-1.5-flash';

  String _apiKey = '';
  String _selectedModel = _defaultModel;
  bool _isInitialized = false;

  String get selectedModel => _selectedModel;
  String get apiKey => _apiKey;

  Future<void> initialize() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_apiKeyPref) ?? '';
    _selectedModel = prefs.getString(_modelPref) ?? _defaultModel;
    _isInitialized = true;
  }

  Future<void> updateApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, _apiKey);
  }

  Future<void> updateModel(String model) async {
    _selectedModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPref, _selectedModel);
  }

  /// Envía un prompt de texto a Gemini
  Future<GoogleAiResponse> generateResponse({
    required String prompt,
    String? model,
  }) async {
    if (!_isInitialized) await initialize();
    if (_apiKey.isEmpty) return GoogleAiResponse.error(error: 'API Key de Google no configurada', model: model ?? _selectedModel);

    final activeModel = model ?? _selectedModel;
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$activeModel:generateContent';
    
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
        body: jsonEncode({
          'contents': [{
            'parts': [{'text': prompt}]
          }],
          'generationConfig': {
             'temperature': 0.7,
          }
        }),
      ).timeout(const Duration(seconds: 30));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        return GoogleAiResponse.success(
          text: content.trim(),
          model: activeModel,
          duration: stopwatch.elapsed,
        );
      } else {
        return GoogleAiResponse.error(
          error: 'Error Google API ${response.statusCode}: ${response.body}',
          model: activeModel,
          duration: stopwatch.elapsed,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return GoogleAiResponse.error(error: e.toString(), model: activeModel, duration: stopwatch.elapsed);
    }
  }

  /// Envía prompt + imagen (base64) a Gemini
  Future<GoogleAiResponse> generateResponseWithImage({
    required String prompt,
    required String imageBase64,
    String? model,
  }) async {
    if (!_isInitialized) await initialize();
    if (_apiKey.isEmpty) return GoogleAiResponse.error(error: 'API Key de Google no configurada', model: model ?? _selectedModel);

    final activeModel = model ?? _selectedModel;
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$activeModel:generateContent';
    
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
        body: jsonEncode({
          'contents': [{
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': imageBase64
                }
              }
            ]
          }],
          'generationConfig': {
             'temperature': 0.4,
          }
        }),
      ).timeout(const Duration(seconds: 60));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        return GoogleAiResponse.success(
          text: content.trim(),
          model: activeModel,
          duration: stopwatch.elapsed,
        );
      } else {
        return GoogleAiResponse.error(
          error: 'Error Google API ${response.statusCode}: ${response.body}',
          model: activeModel,
          duration: stopwatch.elapsed,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return GoogleAiResponse.error(error: e.toString(), model: activeModel, duration: stopwatch.elapsed);
    }
  }

  /// Obtiene la lista de modelos disponibles en Google AI
  Future<List<String>> getAvailableModels() async {
    if (!_isInitialized) await initialize();
    if (_apiKey.isEmpty) return [];

    final url = 'https://generativelanguage.googleapis.com/v1beta/models';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> models = data['models'] ?? [];
        
        // Filtrar modelos que soporten generateContent y que sean de la familia gemini
        return models
            .where((m) {
              final String name = m['name'] ?? '';
              final List<dynamic> methods = m['supportedGenerationMethods'] ?? [];
              return name.contains('gemini') && methods.contains('generateContent');
            })
            .map((m) => (m['name'] as String).replaceFirst('models/', ''))
            .toList();
      }
    } catch (e) {
      debugPrint('GoogleAiService: Error obteniendo modelos - $e');
    }
    return [];
  }
}
