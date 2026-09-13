import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartz/dartz.dart';

class AiResult<T> {
  final T? data;
  final bool isError;
  final String? errorMessage;
  final String? rawResponse;

  AiResult.success(this.data, {this.rawResponse})
      : isError = false,
        errorMessage = null;

  AiResult.error(this.errorMessage, {this.rawResponse})
      : data = null,
        isError = true;
}

class AiVisionTask {
  final Uint8List imageBytes;
  final String prompt;

  AiVisionTask({required this.imageBytes, required this.prompt});
}

class AiTextTask {
  final String prompt;
  final String? systemMessage;

  AiTextTask({required this.prompt, this.systemMessage});
}

abstract class AiModelAdapter {
  bool get supportsVision;
  Future<AiResult<Map<String, dynamic>>> visionTask(AiVisionTask task);
  Future<AiResult<Map<String, dynamic>>> textTask(AiTextTask task);
}

class AiOrchestrator {
  static final AiOrchestrator _instance = AiOrchestrator._internal();
  factory AiOrchestrator() => _instance;
  AiOrchestrator._internal();

  final Map<String, AiModelAdapter> _adapters = {};
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final int _cacheTtlSeconds = 300;

  String? _activeProfileId;
  AiModelAdapter? _activeAdapter;
  List<AiModelAdapter> _fallbackChain = [];

  Map<String, AiModelAdapter> get adapters => _adapters;

  void registerAdapter(String profileId, AiModelAdapter adapter) {
    _adapters[profileId] = adapter;
    if (_activeProfileId == null) {
      _activeProfileId = profileId;
      _activeAdapter = adapter;
    }
  }

  void setActiveProfile(String profileId) {
    if (_adapters.containsKey(profileId)) {
      _activeProfileId = profileId;
      _activeAdapter = _adapters[profileId];
      debugPrint('AiOrchestrator: Active profile set to $profileId');
    }
  }

  void setFallbackChain(List<String> profileIds) {
    _fallbackChain = profileIds
        .where((id) => _adapters.containsKey(id))
        .map((id) => _adapters[id]!)
        .toList();
  }

  AiModelAdapter? get activeAdapter => _activeAdapter;
  String? get activeProfileId => _activeProfileId;

  Future<AiResult<Map<String, dynamic>>> executeVisionTask(
    Uint8List imageBytes,
    String prompt, {
    int maxRetries = 3,
    bool useFallback = true,
  }) async {
    if (_activeAdapter == null) {
      return AiResult.error('No AI profile active');
    }

    if (_activeAdapter?.supportsVision != true) {
      return AiResult.error('Active profile does not support vision');
    }

    final cacheKey = _generateCacheKey(prompt, imageBytes);
    final cached = _getCachedResult(cacheKey);
    if (cached != null) return cached;

    int attempts = 0;
    Exception? lastError;

    while (attempts < maxRetries) {
      try {
        final result = await _activeAdapter!.visionTask(
          AiVisionTask(imageBytes: imageBytes, prompt: prompt),
        );

        if (!result.isError && result.data != null) {
          _cacheResult(cacheKey, result.data!);
          return result;
        }

        if (!useFallback || _fallbackChain.isEmpty) {
          return result;
        }

        for (final fallbackAdapter in _fallbackChain) {
          if (!fallbackAdapter.supportsVision) continue;

          try {
            final fallbackResult = await fallbackAdapter.visionTask(
              AiVisionTask(imageBytes: imageBytes, prompt: prompt),
            );
            if (!fallbackResult.isError && fallbackResult.data != null) {
              _cacheResult(cacheKey, fallbackResult.data!);
              return fallbackResult;
            }
          } catch (e) {
            continue;
          }
        }

        return result;
      } catch (e) {
        attempts++;
        lastError = e as Exception;
        if (attempts < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }
    }

    return AiResult.error('Error después de $maxRetries intentos: $lastError');
  }

  Future<AiResult<Map<String, dynamic>>> executeTextTask(
    String prompt, {
    String? systemMessage,
    int maxRetries = 3,
    bool useFallback = true,
  }) async {
    if (_activeAdapter == null) {
      return AiResult.error('Ningún modelo configurado');
    }

    final cacheKey = _generateCacheKey(prompt, null);
    final cached = _getCachedResult(cacheKey);
    if (cached != null) return cached;

    int attempts = 0;
    Exception? lastError;

    while (attempts < maxRetries) {
      try {
        final result = await _activeAdapter!.textTask(
          AiTextTask(prompt: prompt, systemMessage: systemMessage),
        );

        if (!result.isError && result.data != null) {
          _cacheResult(cacheKey, result.data!);
          return result;
        }

        if (!useFallback || _fallbackChain.isEmpty) {
          return result;
        }

        for (final fallbackAdapter in _fallbackChain) {
          try {
            final fallbackResult = await fallbackAdapter.textTask(
              AiTextTask(prompt: prompt, systemMessage: systemMessage),
            );
            if (!fallbackResult.isError && fallbackResult.data != null) {
              _cacheResult(cacheKey, fallbackResult.data!);
              return fallbackResult;
            }
          } catch (e) {
            continue;
          }
        }

        return result;
      } catch (e) {
        attempts++;
        lastError = e as Exception;
        if (attempts < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }
    }

    return AiResult.error('Error después de $maxRetries intentos: $lastError');
  }

  String _generateCacheKey(String prompt, Uint8List? imageBytes) {
    if (imageBytes != null) {
      final imageHash = imageBytes.hashCode;
      return '${prompt.hashCode}_$imageHash';
    }
    return prompt.hashCode.toString();
  }

  AiResult<Map<String, dynamic>>? _getCachedResult(String key) {
    final cached = _cache[key];
    if (cached == null) return null;

    final timestamp = cached.first['_timestamp'] as int?;
    if (timestamp == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - timestamp > _cacheTtlSeconds * 1000) {
      _cache.remove(key);
      return null;
    }

    final data = Map<String, dynamic>.from(cached.first);
    data.remove('_timestamp');
    return AiResult.success(data);
  }

  void _cacheResult(String key, Map<String, dynamic> data) {
    data['_timestamp'] = DateTime.now().millisecondsSinceEpoch;
    _cache[key] = [data];
  }

  void clearCache() {
    _cache.clear();
  }

  void invalidateCache(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  bool _validateResponse(Map<String, dynamic> data, List<String> requiredKeys) {
    for (final key in requiredKeys) {
      if (!data.containsKey(key)) return false;
    }
    return true;
  }

  Future<AiResult<T>> executeStructuredTask<T>(
    AiTextTask task, {
    required T Function(Map<String, dynamic>) decoder,
    int maxRetries = 3,
    bool useFallback = true,
    String? jsonSchema,
  }) async {
    final prompt = jsonSchema != null
        ? '${task.prompt}\\n\\nReturn the response strictly as JSON following this schema: $jsonSchema'
        : task.prompt;

    final textTask =
        AiTextTask(prompt: prompt, systemMessage: task.systemMessage);
    final result = await executeTextTask(
      textTask.prompt,
      systemMessage: textTask.systemMessage,
      maxRetries: maxRetries,
      useFallback: useFallback,
    );

    if (result.isError) {
      return AiResult.error(result.errorMessage!,
          rawResponse: result.rawResponse);
    }

    try {
      final data = result.data;
      if (data == null) return AiResult.error('Empty response from AI');
      return AiResult.success(decoder(data), rawResponse: result.rawResponse);
    } catch (e) {
      return AiResult.error('Failed to parse structured response: $e',
          rawResponse: result.rawResponse);
    }
  }
}
