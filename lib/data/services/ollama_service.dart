import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Tipo de conexión del servidor
enum ServerType { local, tailscale }

/// Modelo de servidor Ollama
class OllamaServer {
  final String id;
  final String name;
  final String url;
  final ServerType type;
  final String icon;

  OllamaServer({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
  }) : icon = type == ServerType.tailscale ? '🌐' : '🏠';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'type': type.index,
      };

  factory OllamaServer.fromJson(Map<String, dynamic> json) => OllamaServer(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        type: ServerType.values[json['type'] as int],
      );

  @override
  String toString() => 'OllamaServer($name: $url)';
}

/// Servidores por defecto. Antes contenían IPs privadas reales (LAN y
/// Tailscale) embebidas en el código; ahora un único servidor neutro que se
/// puede editar desde Ajustes. Los servidores guardados por el usuario en
/// preferencias tienen prioridad sobre estos defaults.
List<OllamaServer> get defaultServers => [
      OllamaServer(
        id: 'server_local',
        name: 'Servidor Local',
        url: 'http://localhost:11434',
        type: ServerType.local,
      ),
    ];

/// Respuesta estructurada del servidor Ollama
class OllamaResponse {
  final bool isSuccess;
  final String text;
  final String model;
  final Duration duration;
  final String? error;

  OllamaResponse({
    required this.isSuccess,
    required this.text,
    required this.model,
    required this.duration,
    this.error,
  });

  /// Crea una respuesta exitosa
  factory OllamaResponse.success({
    required String text,
    required String model,
    required Duration duration,
  }) {
    return OllamaResponse(
      isSuccess: true,
      text: text,
      model: model,
      duration: duration,
      error: null,
    );
  }

  /// Crea una respuesta de error
  factory OllamaResponse.error({
    required String error,
    required String model,
    Duration? duration,
  }) {
    return OllamaResponse(
      isSuccess: false,
      text: '',
      model: model,
      duration: duration ?? Duration.zero,
      error: error,
    );
  }

  @override
  String toString() {
    return 'OllamaResponse(success: $isSuccess, model: $model, duration: ${duration.inMilliseconds}ms, error: $error)';
  }
}

/// Servicio para conectar con Ollama - Soporta múltiples servidores
/// Singleton pattern para reutilización eficiente de conexiones
class OllamaService {
  static final OllamaService _instance = OllamaService._internal();

  factory OllamaService() {
    return _instance;
  }

  OllamaService._internal();

  /// Keys para SharedPreferences
  static const String _serversKey = 'ollama_servers';
  static const String _activeServerKey = 'ollama_active_server';
  static const String _modelKey = 'ollama_selected_model';

  /// Modelo por defecto
  String _selectedModel = 'llava:7b';

  /// Timeout para solicitudes de texto (60 segundos)
  static const Duration _timeout = Duration(seconds: 60);

  /// Timeout para solicitudes con imagen (90 segundos)
  static const Duration _visionTimeout = Duration(seconds: 90);

  /// Máximo número de reintentos
  static const int _maxRetries = 2;

  /// Cliente HTTP compartido
  late http.Client _httpClient;

  bool _isInitialized = false;
  bool _serverAvailable = false;
  Future<void>? _initializationFuture;

  /// Lista de servidores configurados
  List<OllamaServer> _servers = [];

  /// Servidor activo actual
  OllamaServer? _activeServer;

  /// Getters
  String get selectedModel => _selectedModel;
  List<OllamaServer> get servers => List.unmodifiable(_servers);
  OllamaServer? get activeServer => _activeServer;
  String get baseUrl => _activeServer?.url ?? '';
  bool get isLoopbackUrl => isLoopback(baseUrl);

  static bool isLoopback(String rawUrl) {
    try {
      final host = Uri.parse(rawUrl).host.toLowerCase();
      return host == 'localhost' || host == '127.0.0.1' || host == '::1';
    } catch (_) {
      return false;
    }
  }

  static String? normalizeUrl(String rawUrl) {
    final value = rawUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return null;
    }
    return uri.toString().replaceAll(RegExp(r'/+$'), '');
  }

  /// Inicializa el servicio y carga config guardada. Las llamadas
  /// concurrentes comparten la misma apertura para no crear varios clientes
  /// HTTP ni leer preferencias en paralelo.
  Future<void> initialize() => _initializationFuture ??= _initialize();

  Future<void> _initialize() async {
    if (_isInitialized) return;

    _httpClient = http.Client();

    try {
      final prefs = await SharedPreferences.getInstance();

      final savedModel = prefs.getString(_modelKey);
      if (savedModel != null && savedModel.isNotEmpty) {
        _selectedModel = savedModel;
      }

      final savedServersJson = prefs.getString(_serversKey);
      if (savedServersJson != null && savedServersJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedServersJson);
        _servers = decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => OllamaServer.fromJson(e))
            .toList();
      }
      if (_servers.isEmpty) _servers = defaultServers;

      final activeServerId = prefs.getString(_activeServerKey);
      if (activeServerId != null) {
        _activeServer = _servers.firstWhere(
          (s) => s.id == activeServerId,
          orElse: () => _servers.first,
        );
      } else if (_servers.isNotEmpty) {
        _activeServer = _servers.first;
      }
    } catch (e) {
      debugPrint('OllamaService: Error cargando config - $e');
      _servers = defaultServers;
      _activeServer = _servers.isNotEmpty ? _servers.first : null;
    }

    _isInitialized = true;
  }

  /// Establece el servidor activo
  Future<void> setActiveServer(String serverId) async {
    final server = _servers.firstWhere(
      (s) => s.id == serverId,
      orElse: () => _servers.first,
    );
    _activeServer = server;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeServerKey, serverId);
    debugPrint('OllamaService: Servidor activo: ${server.name}');

    await _checkServerAvailability();
  }

  /// Añade un nuevo servidor
  Future<void> addServer(OllamaServer server) async {
    final existing = _servers.indexWhere((s) => s.id == server.id);
    if (existing >= 0) {
      _servers[existing] = server;
    } else {
      _servers.add(server);
    }
    await _saveServers();
  }

  /// Elimina un servidor
  Future<void> removeServer(String serverId) async {
    _servers.removeWhere((s) => s.id == serverId);
    if (_activeServer?.id == serverId && _servers.isNotEmpty) {
      _activeServer = _servers.first;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeServerKey, _activeServer!.id);
    }
    await _saveServers();
  }

  /// Actualiza un servidor existente
  Future<void> updateServer(OllamaServer server) async {
    final index = _servers.indexWhere((s) => s.id == server.id);
    if (index >= 0) {
      _servers[index] = server;
      if (_activeServer?.id == server.id) {
        _activeServer = server;
      }
      await _saveServers();
      await _checkServerAvailability();
    }
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_servers.map((s) => s.toJson()).toList());
    await prefs.setString(_serversKey, encoded);
  }

  /// Actualiza la URL del servidor activo
  Future<void> updateBaseUrl(String newUrl) async {
    if (_activeServer != null) {
      final normalized = normalizeUrl(newUrl);
      if (normalized == null) {
        debugPrint('OllamaService: URL no válida: $newUrl');
        return;
      }
      final updated = OllamaServer(
        id: _activeServer!.id,
        name: _activeServer!.name,
        url: normalized,
        type: _activeServer!.type,
      );
      await updateServer(updated);
    }
  }

  /// Actualiza el modelo seleccionado
  Future<void> updateModel(String newModel) async {
    _selectedModel = newModel;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, _selectedModel);
    debugPrint('OllamaService: Modelo actualizado a $_selectedModel');
  }

  /// Verifica si el servidor Ollama está disponible
  Future<void> _checkServerAvailability() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(const Duration(seconds: 5));

      _serverAvailable = response.statusCode == 200;
      debugPrint(
          'OllamaService: Server availability check - $_serverAvailable ($baseUrl)');
    } catch (e) {
      _serverAvailable = false;
      debugPrint('OllamaService: Server not available - $e');
    }
  }

  /// Obtiene la lista de modelos instalados en Ollama
  Future<List<String>> getInstalledModels() async {
    if (!_isInitialized) await initialize();

    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List? ?? [])
            .map((m) => m['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        models.sort();
        return models;
      }
    } catch (e) {
      debugPrint('OllamaService: Error listando modelos - $e');
    }
    return [];
  }

  /// Obtiene la lista de modelos en ejecución
  Future<List<String>> getRunningModels() async {
    if (!_isInitialized) await initialize();
    try {
      final response = await _httpClient.get(Uri.parse('$baseUrl/api/ps'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['models'] as List? ?? [])
            .map((m) => m['name']?.toString() ?? '')
            .toList();
      }
    } catch (e) {
      debugPrint('OllamaService: Error listando modelos en ejecución - $e');
    }
    return [];
  }

  /// Descarga un modelo (Stream)
  Stream<String> pullModel(String model) async* {
    if (!_isInitialized) await initialize();
    final request = http.Request('POST', Uri.parse('$baseUrl/api/pull'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'name': model, 'stream': true});

    final response = await _httpClient.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw StateError('Ollama HTTP ${response.statusCode}: $body');
    }

    // Acumula el buffer: los chunks de red NO están alineados a líneas y
    // partir cada chunk por '\n' generaba JSON parciales → errores de
    // parseo intermitentes durante la descarga.
    String buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final newlineIndex = buffer.indexOf('\n');
        if (newlineIndex < 0) break;
        final line = buffer.substring(0, newlineIndex).trim();
        buffer = buffer.substring(newlineIndex + 1);
        if (line.isEmpty) continue;
        try {
          final json = jsonDecode(line);
          if (json.containsKey('status')) {
            yield json['status'];
          }
        } catch (e) {
          debugPrint('Error parsing pull stream: $e');
        }
      }
    }
    final rest = buffer.trim();
    if (rest.isNotEmpty) {
      try {
        final json = jsonDecode(rest);
        if (json.containsKey('status')) {
          yield json['status'];
        }
      } catch (_) {}
    }
  }

  /// Elimina un modelo
  Future<bool> deleteModel(String model) async {
    if (!_isInitialized) await initialize();
    try {
      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/api/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': model}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('OllamaService: Error eliminando modelo - $e');
      return false;
    }
  }

  /// Genera una respuesta de Ollama (solo texto)
  Future<OllamaResponse> generateResponse({
    required String prompt,
    required String model,
    String? context,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_serverAvailable) {
      // Reintentar verificación antes de fallar
      await _checkServerAvailability();
      if (!_serverAvailable) {
        return OllamaResponse.error(
          error:
              'No se pudo conectar con el servidor ($baseUrl). Verifica que Tailscale esté ACTIVO en este dispositivo y que tu servidor Ollama esté encendido.',
          model: model,
        );
      }
    }

    return _retryWithBackoff(
      () => _sendRequest(
        prompt: prompt,
        model: model,
        context: context,
        keepAlive: '1h',
      ),
    );
  }

  /// Genera una respuesta de Ollama con imagen (para LLaVA y modelos de visión)
  Future<OllamaResponse> generateResponseWithImage({
    required String prompt,
    required String model,
    required String imageBase64,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_serverAvailable) {
      await _checkServerAvailability();
      if (!_serverAvailable) {
        return OllamaResponse.error(
          error:
              'No se pudo conectar con el servidor ($baseUrl) para visión. Verifica que Tailscale esté ACTIVO en este dispositivo y que tu servidor Ollama esté encendido.',
          model: model,
        );
      }
    }

    return _retryWithBackoff(
      () => _sendRequestWithImage(
        prompt: prompt,
        model: model,
        imageBase64: imageBase64,
      ),
    );
  }

  Future<OllamaResponse> _sendRequest({
    required String prompt,
    required String model,
    String? context,
    String? keepAlive,
  }) async {
    final stopwatch = Stopwatch()..start();
    final url = '$baseUrl/api/generate';

    try {
      final body = {
        'model': model,
        'prompt': prompt,
        'stream': false,
        if (context != null) 'context': context,
        if (keepAlive != null) 'keep_alive': keepAlive,
        'options': {
          'temperature': 0.7,
          'top_p': 0.9,
        },
      };

      debugPrint(
          'OllamaService: Enviando solicitud texto a Ollama (modelo: $model)');

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      stopwatch.stop();

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final jsonResponse = jsonDecode(decodedBody);
        final responseText = jsonResponse['response'] as String? ?? '';

        debugPrint(
            'OllamaService: Respuesta exitosa en ${stopwatch.elapsedMilliseconds}ms');

        return OllamaResponse.success(
          text: responseText.trim(),
          model: model,
          duration: stopwatch.elapsed,
        );
      } else {
        final body = utf8.decode(response.bodyBytes).trim();
        final error =
            'Error HTTP ${response.statusCode}: ${body.isEmpty ? response.reasonPhrase : body}';
        debugPrint('OllamaService: $error');
        return OllamaResponse.error(
          error: error,
          model: model,
          duration: stopwatch.elapsed,
        );
      }
    } on TimeoutException {
      stopwatch.stop();
      final timeoutError =
          'Timeout: Servidor no respondió en ${_timeout.inSeconds} segundos';
      debugPrint('OllamaService: $timeoutError');
      return OllamaResponse.error(
        error: timeoutError,
        model: model,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      final errorMsg = 'Error de conexión: $e';
      debugPrint('OllamaService: $errorMsg');
      return OllamaResponse.error(
        error: errorMsg,
        model: model,
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Envía una solicitud HTTP a Ollama con imagen (para LLaVA)
  Future<OllamaResponse> _sendRequestWithImage({
    required String prompt,
    required String model,
    required String imageBase64,
  }) async {
    final stopwatch = Stopwatch()..start();
    final url = '$baseUrl/api/generate';

    try {
      final body = {
        'model': model,
        'prompt': prompt,
        'stream': false,
        'images': [imageBase64],
        'options': {
          'temperature': 0.3, // Más determinístico para análisis de comida
          'top_p': 0.9,
        },
      };

      debugPrint(
          'OllamaService: Enviando solicitud con imagen a Ollama (modelo: $model)');

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_visionTimeout);

      stopwatch.stop();

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final jsonResponse = jsonDecode(decodedBody);
        final responseText = jsonResponse['response'] as String? ?? '';

        debugPrint(
            'OllamaService: Respuesta visión exitosa en ${stopwatch.elapsedMilliseconds}ms');

        return OllamaResponse.success(
          text: responseText.trim(),
          model: model,
          duration: stopwatch.elapsed,
        );
      } else {
        final body = utf8.decode(response.bodyBytes).trim();
        final error =
            'Error HTTP ${response.statusCode}: ${body.isEmpty ? response.reasonPhrase : body}';
        debugPrint('OllamaService: $error');
        return OllamaResponse.error(
          error: error,
          model: model,
          duration: stopwatch.elapsed,
        );
      }
    } on TimeoutException {
      stopwatch.stop();
      final timeoutError =
          'Timeout: Servidor no respondió en ${_visionTimeout.inSeconds} segundos';
      debugPrint('OllamaService: $timeoutError');
      return OllamaResponse.error(
        error: timeoutError,
        model: model,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      final errorMsg = 'Error de conexión: $e';
      debugPrint('OllamaService: $errorMsg');
      return OllamaResponse.error(
        error: errorMsg,
        model: model,
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Reintentos con backoff exponencial.
  /// NO reintenta errores 4xx (modelo inexistente, petición malformada…):
  /// antes multiplicaba esperas hasta ~90 s por un error que nunca iba a
  /// cambiar entre intentos.
  Future<OllamaResponse> _retryWithBackoff(
    Future<OllamaResponse> Function() operation,
  ) async {
    int attempt = 0;
    late OllamaResponse lastResponse;

    while (attempt <= _maxRetries) {
      lastResponse = await operation();

      if (lastResponse.isSuccess) {
        return lastResponse;
      }

      final error = lastResponse.error ?? '';
      final match = RegExp(r'Error HTTP (\d{3})').firstMatch(error);
      final statusCode = match != null ? int.parse(match.group(1)!) : null;
      // 4xx = error del cliente: reintentar no cambia el resultado.
      if (statusCode != null && statusCode >= 400 && statusCode < 500) {
        debugPrint('OllamaService: error $statusCode sin reintento ($error)');
        return lastResponse;
      }

      attempt++;

      if (attempt <= _maxRetries) {
        final delay = Duration(seconds: 1 * attempt);
        debugPrint(
            'OllamaService: Reintentando en ${delay.inSeconds}s (intento $attempt/$_maxRetries)');
        await Future.delayed(delay);
      }
    }

    return lastResponse;
  }

  /// Verifica si el servidor está disponible sin hacer una solicitud pesada
  Future<bool> isServerAvailable() async {
    if (!_isInitialized) {
      await initialize();
    }
    await _checkServerAvailability();
    return _serverAvailable;
  }

  /// Limpia recursos
  void dispose() {
    if (_isInitialized) {
      _httpClient.close();
      _isInitialized = false;
      _initializationFuture = null;
    }
  }

  /// Obtiene el estado actual del servidor
  bool get serverStatusOK => _serverAvailable;
}
