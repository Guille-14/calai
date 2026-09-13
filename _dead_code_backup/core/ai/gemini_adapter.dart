import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_orchestrator.dart';

class GeminiAdapter implements AiModelAdapter {
  final String apiKey;
  final String model;
  final String baseUrl;

  GeminiAdapter({
    required this.apiKey,
    required this.model,
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  });

  @override
  bool get supportsVision {
    final visionModels = [
      'gemini-pro-vision',
      'gemini-1.5-pro',
      'gemini-1.5-flash',
      'gemini-2.0-flash-exp',
    ];
    return visionModels.any((m) => model.toLowerCase().contains(m));
  }

  @override
  Future<AiResult<Map<String, dynamic>>> visionTask(AiVisionTask task) async {
    try {
      final base64Image = base64Encode(task.imageBytes);

      final uri =
          Uri.parse('$baseUrl/models/$model:generateContent?key=$apiKey');

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': task.prompt},
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 32,
          'topP': 0.9,
          'maxOutputTokens': 4096,
        }
      });

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];

        try {
          final parsed = jsonDecode(content);
          return AiResult.success(parsed);
        } catch (_) {
          return AiResult.success({'raw_response': content});
        }
      } else {
        final error = jsonDecode(response.body);
        return AiResult.error(
            error['error']?['message'] ?? 'Error en la llamada');
      }
    } catch (e) {
      return AiResult.error('Error de red: $e');
    }
  }

  @override
  Future<AiResult<Map<String, dynamic>>> textTask(AiTextTask task) async {
    try {
      final uri =
          Uri.parse('$baseUrl/models/$model:generateContent?key=$apiKey');

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': task.prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 32,
          'topP': 0.9,
          'maxOutputTokens': 4096,
        }
      });

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];

        try {
          final parsed = jsonDecode(content);
          return AiResult.success(parsed);
        } catch (_) {
          return AiResult.success({'raw_response': content});
        }
      } else {
        final error = jsonDecode(response.body);
        return AiResult.error(
            error['error']?['message'] ?? 'Error en la llamada');
      }
    } catch (e) {
      return AiResult.error('Error de red: $e');
    }
  }
}
