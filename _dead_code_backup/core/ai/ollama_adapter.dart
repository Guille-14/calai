import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ai_orchestrator.dart';
import '../../data/services/ollama_service.dart';

/// Adaptador que implementa la interfaz AiModelAdapter para Ollama
/// Soporta tanto texto como visión (LLaVA) vía Tailscale
class OllamaAdapter implements AiModelAdapter {
  final OllamaService _ollamaService = OllamaService();
  final String model;

  OllamaAdapter({
    this.model = 'llava:7b',
  });

  @override
  bool get supportsVision => true; // LLaVA soporta visión

  /// Ejecuta una tarea de visión enviando la imagen como base64 al modelo LLaVA
  @override
  Future<AiResult<Map<String, dynamic>>> visionTask(AiVisionTask task) async {
    try {
      debugPrint('OllamaAdapter: Ejecutando visionTask con modelo $model');

      final base64Image = base64Encode(task.imageBytes);

      final response = await _ollamaService.generateResponseWithImage(
        prompt: task.prompt,
        model: model,
        imageBase64: base64Image,
      );

      if (response.isSuccess) {
        debugPrint(
            'OllamaAdapter: Visión exitosa (${response.duration.inMilliseconds}ms)');

        try {
          final parsed = jsonDecode(response.text);
          return AiResult.success(parsed);
        } catch (_) {
          return AiResult.success({'raw_response': response.text});
        }
      } else {
        debugPrint('OllamaAdapter: Error visión - ${response.error}');
        return AiResult.error(
          'Error de Ollama (visión): ${response.error}',
          rawResponse: response.error,
        );
      }
    } catch (e) {
      debugPrint('OllamaAdapter: Excepción en visión - $e');
      return AiResult.error('Excepción en OllamaAdapter (visión): $e');
    }
  }

  /// Ejecuta una tarea de texto usando Ollama
  @override
  Future<AiResult<Map<String, dynamic>>> textTask(AiTextTask task) async {
    try {
      debugPrint('OllamaAdapter: Ejecutando textTask con modelo $model');

      // Construir prompt completo con mensaje del sistema si existe
      final fullPrompt = task.systemMessage != null
          ? '${task.systemMessage}\n\n${task.prompt}'
          : task.prompt;

      // Solicitar respuesta a Ollama
      final response = await _ollamaService.generateResponse(
        prompt: fullPrompt,
        model: model,
      );

      if (response.isSuccess) {
        debugPrint(
            'OllamaAdapter: Respuesta exitosa (${response.duration.inMilliseconds}ms)');

        try {
          final parsed = jsonDecode(response.text);
          return AiResult.success(parsed);
        } catch (_) {
          return AiResult.success({'raw_response': response.text});
        }
      } else {
        debugPrint('OllamaAdapter: Error - ${response.error}');

        return AiResult.error(
          'Error de Ollama: ${response.error}',
          rawResponse: response.error,
        );
      }
    } catch (e) {
      debugPrint('OllamaAdapter: Excepción no manejada - $e');
      return AiResult.error('Excepción en OllamaAdapter: $e');
    }
  }

  /// Inicializa el servicio
  Future<void> initialize() async {
    await _ollamaService.initialize();
  }

  /// Verifica disponibilidad del servidor Ollama
  Future<bool> checkServerHealth() async {
    return await _ollamaService.isServerAvailable();
  }

  /// Limpia recursos
  void dispose() {
    _ollamaService.dispose();
  }
}
