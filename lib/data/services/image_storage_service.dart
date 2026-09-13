import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();

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
