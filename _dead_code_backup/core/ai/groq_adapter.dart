
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_orchestrator.dart';

class GroqAdapter implements AiModelAdapter {
  final String apiKey;
  final String model;
  final String baseUrl;

  GroqAdapter({
    required this.apiKey,
    required this.model,
    this.baseUrl = 'https://api.groq.com/openai/v1',
  });

  @override
  bool get supportsVision {
    // Current Groq models don't support vision, but we can add when available
    final visionModels = [
      'llava-v1.5-7b-4096-preview',
    ];
    return visionModels.any((m) => model.toLowerCase().contains(m));
  }

  @override
  Future<AiResult<Map<String, dynamic>>> visionTask(AiVisionTask task) async {
    if (!supportsVision) {
      return AiResult.error('Modelo actual no soporta visión');
    }

    try {
      final base64Image = base64Encode(task.imageBytes);

      final uri = Uri.parse('$baseUrl/chat/completions');

      final body = jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': task.prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
              },
            ],
          },
        ],
        'max_tokens': 4096,
      });

      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

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
      final uri = Uri.parse('$baseUrl/chat/completions');

      final messages = <Map<String, dynamic>>[];

      if (task.systemMessage != null) {
        messages.add({'role': 'system', 'content': task.systemMessage});
      }
      messages.add({'role': 'user', 'content': task.prompt});

      final body = jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': 4096,
        'temperature': 0.7,
        'top_p': 0.9,
        'stream': false,
        'stop': null,
      });

      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

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
