import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Punto único de acceso a las claves de API sensibles (Gemini, OpenRouter).
///
/// Antes vivían en SharedPreferences (fichero en texto plano en el
/// dispositivo). Ahora se guardan con flutter_secure_storage
/// (Android Keystore / encryptedSharedPreferences, iOS Keychain) y se hace
/// una migración automática one-shot: si la clave sigue en la clave legacy
/// de SharedPreferences y no existe en el almacenamiento seguro, se MUVE
/// (se escribe en el seguro y se borra la de prefs). Si ya está en el
/// seguro, o no existe en ninguna, no pasa nada.
class ApiKeyStore {
  ApiKeyStore._();

  // encryptedSharedPreferences: más fiable que el Keymaster nativo en
  // emuladores y dispositivos sin biometría; sigue siendo cifrado a disco.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const Map<String, String> _legacyPrefKeys = {
    'gemini': 'google_ai_api_key',
    'openrouter': 'openrouter_api_key',
  };

  /// Devuelve la clave para [id] ('gemini' | 'openrouter'), migrándola de
  /// SharedPreferences si aún no está en el almacenamiento seguro.
  ///
  /// [envFallback] se usa solo si la clave no existe ni en el seguro ni en
  /// prefs (p. ej. OPENROUTER_API_KEY del .env).
  static Future<String> get({
    required String id,
    String envFallback = '',
  }) async {
    try {
      final secure = await _storage.read(key: id);
      if (secure != null && secure.isNotEmpty) return secure;

      final legacyKey = _legacyPrefKeys[id];
      if (legacyKey != null) {
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString(legacyKey);
        if (legacy != null && legacy.isNotEmpty) {
          await _storage.write(key: id, value: legacy);
          await prefs.remove(legacyKey); // mover: escribir en seguro y borrar
          debugPrint(
              'ApiKeyStore: clave "$id" migrada de SharedPreferences al almacenamiento seguro');
          return legacy;
        }
      }
    } catch (e) {
      // Almacenamiento seguro no disponible (tests, permisos denegados):
      // cae al fallback de prefs/.env para no romper el funcionamiento.
      debugPrint('ApiKeyStore: error leyendo storage seguro: $e');
      try {
        final legacyKey = _legacyPrefKeys[id];
        if (legacyKey != null) {
          final prefs = await SharedPreferences.getInstance();
          final legacy = prefs.getString(legacyKey);
          if (legacy != null && legacy.isNotEmpty) return legacy;
        }
      } catch (_) {}
    }
    return envFallback;
  }

  /// Guarda (o borra, si [value] está vacío) la clave en el almacenamiento
  /// seguro y elimina la clave legacy de SharedPreferences si seguía ahí.
  static Future<void> set({required String id, required String value}) async {
    final v = value.trim();
    var secureOk = false;
    try {
      if (v.isEmpty) {
        await _storage.delete(key: id);
      } else {
        await _storage.write(key: id, value: v);
      }
      secureOk = true;
    } catch (e) {
      // Almacenamiento seguro no disponible: se deja en prefs para no
      // perder la clave (peor que ideal, pero no la rompe). En la próxima
      // lectura get() la migrará de nuevo al seguro si ya está disponible.
      debugPrint('ApiKeyStore: no se pudo guardar en storage seguro: $e');
      try {
        final legacyKey = _legacyPrefKeys[id];
        if (legacyKey != null && v.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(legacyKey, v);
        }
      } catch (_) {}
    }

    // La clave legacy solo se borra si el seguro aceptó la nueva.
    if (secureOk) {
      try {
        final legacyKey = _legacyPrefKeys[id];
        if (legacyKey != null) {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.containsKey(legacyKey)) {
            await prefs.remove(legacyKey);
          }
        }
      } catch (_) {}
    }
  }
}
