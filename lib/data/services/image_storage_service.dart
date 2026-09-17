import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Almacenamiento de fotos y normalización de imágenes para los proveedores IA.
class ImageStorageService {
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();

  static const int maxAiSide = 1024;
  static const int aiJpegQuality = 85;

  /// Devuelve un JPEG de tamaño y calidad previsibles para Gemini, Ollama y
  /// OpenRouter. Si la entrada no es decodificable se devuelve intacta: el
  /// proveedor podrá emitir un error explícito en lugar de perder la foto.
  Future<Uint8List> prepareForAi(Uint8List imageBytes) async {
    // Decodificar y redimensionar una foto de cámara en el isolate de UI
    // provocaba tirones justo al pulsar Analizar.
    return compute(_prepareForAi, imageBytes);
  }

  static Uint8List _prepareForAi(Uint8List imageBytes) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return imageBytes;

      final longestSide = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      final resized = longestSide > maxAiSide
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height
                  ? maxAiSide
                  : (decoded.width * maxAiSide / decoded.height).round(),
              height: decoded.height >= decoded.width
                  ? maxAiSide
                  : (decoded.height * maxAiSide / decoded.width).round(),
            )
          : decoded;
      return Uint8List.fromList(img.encodeJpg(resized, quality: aiJpegQuality));
    } catch (_) {
      return imageBytes;
    }
  }

  Future<String> saveFoodImage(Uint8List imageBytes, String foodId) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/food_images');

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName = '${foodId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = '${imagesDir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(imageBytes);

    return filePath;
  }

  Future<File?> getFoodImage(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<void> deleteFoodImage(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteAllImages() async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/food_images');

    if (await imagesDir.exists()) {
      await imagesDir.delete(recursive: true);
    }
  }
}
