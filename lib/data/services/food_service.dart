import 'dart:typed_data';

import 'ai_gateway.dart';

export '../models/food_analysis_result.dart';
export '../models/symmetry_routine_analysis.dart';

/// Fachada de compatibilidad para módulos legacy.
///
/// Las pantallas nuevas deben depender de [AiGateway]. Esta clase conserva la
/// API estática existente mientras se migran los consumidores por contexto,
/// evitando una migración peligrosa y simultánea de toda la aplicación.
@Deprecated('Usa AiGateway en código nuevo')
class FoodService {
  static Future<void> initFromPrefs() => AiGateway.initFromPrefs();

  static String get activeProvider => AiGateway.activeProvider;
  static String get model => AiGateway.model;
  static String? get apiKey => AiGateway.apiKey;

  static Future<void> setProvider(String provider) =>
      AiGateway.setProvider(provider);
  static void setModel(String model) => AiGateway.setModel(model);
  static void setApiKey(String key) => AiGateway.setApiKey(key);
  static Future<void> syncWithAiConfig() => AiGateway.syncWithAiConfig();

  static Future<FoodAnalysisResult> analyzeFoodImageFromBytes(
    Uint8List imageBytes,
  ) => AiGateway.analyzeFoodImageFromBytes(imageBytes);

  static Future<FoodAnalysisResult> estimateCaloriesFromText(
    String description,
  ) => AiGateway.estimateCaloriesFromText(description);

  static Future<SymmetryRoutineAnalysisResult>
      analyzeSymmetryRoutineFromBytes(
    Uint8List imageBytes,
    String muscleGroup,
  ) => AiGateway.analyzeSymmetryRoutineFromBytes(imageBytes, muscleGroup);

  static Future<String> chatCompletion(
    String userMessage, {
    List<String>? context,
  }) => AiGateway.chatCompletion(userMessage, context: context);

  static Future<String> generateNutritionSummary(
    List<Map<String, dynamic>> entries,
  ) => AiGateway.generateNutritionSummary(entries);

  static Future<bool> testConnection() => AiGateway.testConnection();
}
