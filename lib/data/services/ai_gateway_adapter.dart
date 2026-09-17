import 'dart:typed_data';

import '../../core/ai/ai_analysis_port.dart';
import '../models/food_analysis_result.dart';
import 'ai_gateway.dart';

/// Adaptador de infraestructura para inyectar el gateway actual en casos de
/// uso que solo necesitan capacidades nutricionales.
class AiGatewayAdapter implements AiAnalysisPort {
  const AiGatewayAdapter();

  @override
  Future<FoodAnalysisResult> analyzeFoodImage(Uint8List imageBytes) {
    return AiGateway.analyzeFoodImageFromBytes(imageBytes);
  }

  @override
  Future<FoodAnalysisResult> estimateCalories(String description) {
    return AiGateway.estimateCaloriesFromText(description);
  }

  @override
  Future<String> generateNutritionSummary(
    List<Map<String, dynamic>> entries,
  ) {
    return AiGateway.generateNutritionSummary(entries);
  }
}
