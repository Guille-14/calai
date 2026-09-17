import 'dart:typed_data';

import '../../data/models/food_analysis_result.dart';

/// Puerto de dominio para las capacidades de IA que necesita la aplicación.
///
/// Los repositorios dependen de este contrato y no de un proveedor concreto,
/// una clase singleton ni una librería HTTP.
abstract interface class AiAnalysisPort {
  Future<FoodAnalysisResult> analyzeFoodImage(Uint8List imageBytes);

  Future<FoodAnalysisResult> estimateCalories(String description);

  Future<String> generateNutritionSummary(
    List<Map<String, dynamic>> entries,
  );
}
