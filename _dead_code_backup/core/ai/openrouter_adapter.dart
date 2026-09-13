import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_orchestrator.dart';

class OpenRouterAdapter implements AiModelAdapter {
  final String apiKey;
  final String model;
  final String baseUrl;
  final bool isCustomProvider;

  OpenRouterAdapter({
    required this.apiKey,
    required this.model,
    this.baseUrl = 'https://openrouter.ai/api/v1',
    this.isCustomProvider = false,
  });

  @override
  bool get supportsVision {
    final visionModels = [
      'gpt-4o',
      'gpt-4o-mini',
      'gpt-4o-search',
      'claude-3.5-sonnet',
      'claude-3.5-haiku',
      'claude-3.7-sonnet',
      'gemini-2.5-flash',
      'gemini-2.5-pro',
      'gemini-3-flash',
      'llama-3.2-11b-vision',
      'llama-4-maverick',
      'llama-4-scout',
      'qwen2.5-vl',
      'qwen3-vl',
    ];
    return visionModels.any((m) => model.toLowerCase().contains(m));
  }

  @override
  Future<AiResult<Map<String, dynamic>>> visionTask(AiVisionTask task) async {
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
              if (!isCustomProvider) 'HTTP-Referer': 'https://calsnap.app',
              if (!isCustomProvider) 'X-Title': 'CalSnap',
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
      });

      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              if (!isCustomProvider) 'HTTP-Referer': 'https://calsnap.app',
              if (!isCustomProvider) 'X-Title': 'CalSnap',
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
