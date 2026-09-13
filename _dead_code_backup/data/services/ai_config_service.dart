import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_profile.dart';

class AiConfigService {
  AiConfigService._privateConstructor();

  static final AiConfigService _instance =
      AiConfigService._privateConstructor();

  static AiConfigService get instance => _instance;

  static const String _profilesKey = 'ai_profiles_list';
  static const String _activeProfileIdKey = 'active_ai_profile_id';

  List<AiProfile>? _cachedProfiles;

  Future<List<AiProfile>> getProfiles() async {
    if (_cachedProfiles != null) return _cachedProfiles!;
    
    final prefs = await SharedPreferences.getInstance();
    final String? profilesJson = prefs.getString(_profilesKey);
    
    if (profilesJson == null) {
      // Initialize with 5 empty profiles if none exist
      _cachedProfiles = List.generate(5, (index) => AiProfile(
        id: 'slot_${index + 1}',
        name: 'Profile ${index + 1}',
        provider: 'openrouter',
        apiKey: '',
        baseUrl: 'https://openrouter.ai/api/v1',
        model: '',
      ));
      await saveProfiles(_cachedProfiles!);
      return _cachedProfiles!;
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(profilesJson);
      _cachedProfiles = decoded.map((json) => AiProfile.fromJson(json)).toList();
      
      // Ensure we have exactly 5 profiles
      if (_cachedProfiles!.length < 5) {
        for (int i = _cachedProfiles!.length; i < 5; i++) {
          _cachedProfiles!.add(AiProfile(
            id: 'slot_${i + 1}',
            name: 'Profile ${i + 1}',
            provider: 'openrouter',
            apiKey: '',
            baseUrl: 'https://openrouter.ai/api/v1',
            model: '',
          ));
        }
        await saveProfiles(_cachedProfiles!);
      } else if (_cachedProfiles!.length > 5) {
        _cachedProfiles = _cachedProfiles!.sublist(0, 5);
        await saveProfiles(_cachedProfiles!);
      }
      
      return _cachedProfiles!;
    } catch (e) {
      debugPrint('Error decoding profiles: $e');
      return [];
    }
  }

  Future<void> saveProfiles(List<AiProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, encoded);
    _cachedProfiles = profiles;
  }

  Future<void> setActiveProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileIdKey, profileId);
    
    // Also update the legacy keys for backward compatibility
    final profiles = await getProfiles();
    final active = profiles.firstWhere((p) => p.id == profileId, orElse: () => profiles.first);
    
    await saveConfig(
      baseUrl: active.baseUrl,
      apiKey: active.apiKey,
      model: active.model,
    );
  }

  Future<AiProfile?> getActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? activeId = prefs.getString(_activeProfileIdKey);
    final profiles = await getProfiles();
    
    if (activeId == null) return profiles.first;
    return profiles.firstWhere((p) => p.id == activeId,
        orElse: () => profiles.first);
  }

  Future<void> saveConfig({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_base_url', baseUrl);
    await prefs.setString('ai_api_key', apiKey);
    await prefs.setString('ai_selected_model', model);
  }

  Future<String?> getApiBaseUrl() async {
    return (await SharedPreferences.getInstance()).getString('ai_base_url');
  }

  Future<String?> getApiKey() async {
    return (await SharedPreferences.getInstance()).getString('ai_api_key');
  }

  Future<String?> getSelectedModel() async {
    return (await SharedPreferences.getInstance())
        .getString('ai_selected_model');
  }

  Future<List<String>> fetchAvailableModels(
    String baseUrl,
    String apiKey,
  ) async {
    final normalizedUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$normalizedUrl/models');

    debugPrint('AiConfigService: Fetching models from $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('AiConfigService: Response status ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final modelsList = data['data'] as List? ?? [];
        final modelIds = modelsList
            .map((m) => m['id']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        modelIds.sort();
        debugPrint('AiConfigService: Found ${modelIds.length} models');
        return modelIds;
      } else if (response.statusCode == 401) {
        throw Exception('API Key inválida. Verifica tu credencial.');
      } else if (response.statusCode == 403) {
        throw Exception(
            'Acceso denegado. La API Key no tiene permisos para listar modelos.');
      } else if (response.statusCode == 404) {
        throw Exception(
            'Endpoint /models no encontrado. Verifica que la Base URL sea correcta.');
      } else {
        String errorMsg;
        try {
          final error = jsonDecode(response.body);
          errorMsg = error['error']?['message'] ?? response.body;
        } catch (_) {
          errorMsg = response.body;
        }
        throw Exception(
            'Error del servidor (${response.statusCode}): $errorMsg');
      }
    } catch (e) {
      debugPrint('Error fetching models: $e');
      return [];
    }
  }

  Future<bool> validateConnection(String baseUrl, String apiKey) async {
    try {
      await fetchAvailableModels(baseUrl, apiKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getEffectiveBaseUrl() async {
    final savedUrl = await getApiBaseUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      return savedUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }
    return null;
  }

  Future<String?> getEffectiveApiKey() async {
    return await getApiKey();
  }

  Future<String?> getEffectiveModel() async {
    return await getSelectedModel();
  }
}

