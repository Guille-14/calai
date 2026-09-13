import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'ai/ai_orchestrator.dart';
import 'ai/ollama_adapter.dart';
import 'ai/fitness_memory_service.dart';
import 'ai/fitness_memory_profile.dart';
import 'ai/readiness_engine.dart';
import 'ai/workout_intelligence.dart';
import 'ai/nutrition_intelligence.dart';
import 'ai/progress_prediction_engine.dart';
import 'ai/contextual_coach.dart';
import 'ai/training_suggestion.dart';
import '../data/services/google_fit_service.dart';

class FitnessAI {
  static FitnessAI? _instance;
  static SharedPreferences? _prefs;

  late final AiOrchestrator _orchestrator;
  late final FitnessMemoryService _memoryService;
  late final ReadinessEngine _readinessEngine;
  late final ProgressPredictionEngine _predictionEngine;
  late final ContextualCoach _coach;

  bool _isInitialized = false;
  bool _ollamaInitialized = false;
  Future<void>? _ollamaInitFuture;

  AiOrchestrator get orchestrator => _orchestrator;

  FitnessAI._();

  static Future<FitnessAI> getInstance() async {
    if (_instance == null) {
      _instance = FitnessAI._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    if (_isInitialized) return;

    _prefs ??= await SharedPreferences.getInstance();

    _orchestrator = AiOrchestrator();

    _memoryService = FitnessMemoryService(_prefs!);
    _readinessEngine = ReadinessEngine();
    _predictionEngine = ProgressPredictionEngine();
    _coach = ContextualCoach(
        _orchestrator, _memoryService, _readinessEngine, _predictionEngine);

    _isInitialized = true;
  }

  Future<void> _ensureOllamaInitialized() async {
    if (_ollamaInitialized) return;

    _ollamaInitFuture ??= _initializeOllama();
    await _ollamaInitFuture;
  }

  Future<void> syncHealthData() async {
    final fitService = GoogleFitService.instance;
    if (await fitService.checkAuthorization()) {
      final data = await fitService.fetchDailyData();
      if (!data.hasError) {
        await _memoryService.updateFromGoogleFit(data, DateTime.now());
      }
    }
  }

  Future<void> _initializeOllama() async {
    if (_ollamaInitialized) return;

    try {
      final ollamaAdapter = OllamaAdapter(model: 'llava:7b');
      await ollamaAdapter.initialize();
      _orchestrator.registerAdapter('ollama_local', ollamaAdapter);
      _orchestrator.setActiveProfile('ollama_local');
      _orchestrator.setFallbackChain(['ollama_local']);
      _ollamaInitialized = true;
      debugPrint('FitnessAI: Ollama lazy initialized');
    } catch (e) {
      debugPrint('FitnessAI: Ollama init failed - $e');
      _ollamaInitialized = true;
    }
  }

  void updateAiConfiguration() {
    _ollamaInitialized = false;
    _ollamaInitFuture = null;
    _ensureOllamaInitialized();
  }

  Future<FitnessMemoryProfile> getMemoryProfile() async {
    return await _memoryService.getProfile();
  }

  Future<void> syncFoodData(List meals, DateTime date) async {
    await _memoryService.updateFromFoodLog(meals.cast(), date);
  }

  Future<void> syncGoogleFitData(GoogleFitDailyData data, DateTime date) async {
    await _memoryService.updateFromGoogleFit(data, date);
  }

  Future<void> syncWorkoutData(dynamic session) async {
    await _memoryService.updateFromWorkout(session);
  }

  Future<void> syncWaterData(int glasses, DateTime date) async {
    await _memoryService.updateWaterIntake(glasses, date);
  }

  Future<ReadinessScore> getReadinessScore() async {
    final profile = await _memoryService.getProfile();
    return await _readinessEngine.calculateReadiness(profile);
  }

  Future<CoachResponse> getCoachResponse(String message) async {
    await _ensureOllamaInitialized();
    return await _coach.generateResponse(message);
  }

  Future<WorkoutRecommendation> getTodayWorkout() async {
    await _ensureOllamaInitialized();
    return await _coach.getTodayWorkoutRecommendation();
  }

  Future<NutritionAnalysis> analyzeNutrition({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double goal,
  }) async {
    final profile = await _memoryService.getProfile();
    final intelligence = NutritionIntelligence(profile);
    return intelligence.analyzeDailyIntake(
      caloriesConsumed: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      calorieGoal: goal,
    );
  }

  Future<TrainingSuggestion> getWorkoutSuggestion(String exerciseName) async {
    await _ensureOllamaInitialized();
    final profile = await _memoryService.getProfile();
    final intelligence = WorkoutIntelligence(profile);
    return intelligence.generateSuggestion(exerciseName);
  }

  Future<ProgressPrediction> getProgressPrediction() async {
    await _ensureOllamaInitialized();
    final profile = await _memoryService.getProfile();
    return await _predictionEngine.predict(profile);
  }

  void clearCache() {
    _orchestrator.clearCache();
  }
}
