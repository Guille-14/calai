import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_orchestrator.dart';

class AnthropicAdapter implements AiModelAdapter {
  final String apiKey;
  final String model;
  final String baseUrl;

  AnthropicAdapter({
    required this.apiKey,
    required this.model,
    this.baseUrl = 'https://api.anthropic.com/v1',
  });

  @override
  bool get supportsVision {
    final visionModels = ['claude-3-opus', 'claude-3-sonnet', 'claude-3-haiku', 'claude-3-5-sonnet'];
    return visionModels.any((m) => model.toLowerCase().contains(m));
  }

  @override
  Future<AiResult<Map<String, dynamic>>> visionTask(AiVisionTask task) async {
    try {
      final base64Image = base64Encode(task.imageBytes);
      final uri = Uri.parse('$baseUrl/messages');

      final body = jsonEncode({
        'model': model,
        'max_tokens': 4096,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': base64Image,
                },
              },
              {'type': 'text', 'text': task.prompt},
            ],
          },
        ],
      });

      final response = await http.post(
        uri,
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'][0]['text'];
        try {
          return AiResult.success(jsonDecode(content));
        } catch (_) {
          return AiResult.success({'raw_response': content});
        }
      } else {
        final error = jsonDecode(response.body);
        return AiResult.error(error['error']?['message'] ?? 'Anthropic API Error');
      }
    } catch (e) {
      return AiResult.error('Anthropic vision task failed: $e');
    }
  }

  @override
  Future<AiResult<Map<String, dynamic>>> textTask(AiTextTask task) async {
    try {
      final uri = Uri.parse('$baseUrl/messages');
      
      final body = jsonEncode({
        'model': model,
        'max_tokens': 4096,
        'system': task.systemMessage,
        'messages': [
          {'role': 'user', 'content': task.prompt},
        ],
      });

      final response = await http.post(
        uri,
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'][0]['text'];
        try {
          return AiResult.success(jsonDecode(content));
        } catch (_) {
          return AiResult.success({'raw_response': content});
        }
      } else {
        final error = jsonDecode(response.body);
        return AiResult.error(error['error']?['message'] ?? 'Anthropic API Error');
      }
    } catch (e) {
      return AiResult.error('Anthropic text task failed: $e');
    }
  }
}
