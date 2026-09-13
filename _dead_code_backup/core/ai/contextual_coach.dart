import 'dart:typed_data';
import 'ai_orchestrator.dart';
import 'fitness_memory_profile.dart';
import 'fitness_memory_service.dart';
import 'readiness_engine.dart';
import 'workout_intelligence.dart';
import 'progress_prediction_engine.dart';

class ContextualCoach {
  final AiOrchestrator _orchestrator;
  final FitnessMemoryService _memoryService;
  final ReadinessEngine _readinessEngine;
  final ProgressPredictionEngine _predictionEngine;

  ContextualCoach(this._orchestrator, this._memoryService,
      this._readinessEngine, this._predictionEngine);

  Future<CoachResponse> generateResponse(String userMessage,
      {Uint8List? image}) async {
    final profile = await _memoryService.getProfile();
    final readiness = await _readinessEngine.calculateReadiness(profile);
    final prediction = await _predictionEngine.predict(profile);
    final contextualSummary = await _memoryService.getContextualSummary();

    final context = _buildContext(profile, readiness, prediction);
    final fullContext =
        'GENERAL SUMMARY:\n$contextualSummary\n\nDETAILED STATE:\n$context';

    final prompt = _buildPrompt(userMessage, fullContext, image != null);

    final result = await _orchestrator.executeTextTask(
      prompt,
      systemMessage: _getSystemPrompt(profile, readiness),
    );

    if (result.isError) {
      return CoachResponse(
        message:
            'Lo siento, tuve un problema al procesar tu solicitud. ¿Podrías intentar de nuevo?',
        type: CoachResponseType.error,
        suggestions: _generateFallbackSuggestions(readiness),
      );
    }

    return _parseResponse(result.data, readiness, profile);
  }

  String _buildContext(FitnessMemoryProfile profile, ReadinessScore readiness,
      ProgressPrediction prediction) {
    final context = StringBuffer();

    context.writeln('=== ESTADO ACTUAL ===');
    context.writeln('Puntuación de準備: ${readiness.score}/100');
    context.writeln('Recomendación: ${readiness.recommendation}');
    context.writeln('');

    context.writeln('=== NUTRICIÓN HOY ===');
    context.writeln(
        'Calorías promedio: ${profile.nutrition.averageCalories.toInt()}');
    context.writeln(
        'Proteína promedio: ${profile.nutrition.averageProtein.toInt()}g');
    context.writeln(
        'Hidratación: ${profile.hydration.goalAchievementRate.toInt()}% meta');
    context.writeln('');

    context.writeln('=== ENTRENAMIENTO ===');
    context.writeln('Consistencia: ${profile.consistency.score.toInt()}%');
    context.writeln(
        'Frecuencia semanal: ${profile.consistency.weeklyFrequency.toInt()} días');
    context.writeln(
        'Duración promedio: ${profile.consistency.averageWorkoutDuration.toInt()} min');
    context.writeln('');

    if (profile.recovery.isOvertraining) {
      context.writeln('⚠️ SEÑAL DE SOBRENTRENAMIENTO');
      context.writeln('');
    }

    context.writeln('=== PROGRESO ===');
    context.writeln(
        'Predicción fuerza: +${prediction.strengthProgress.toStringAsFixed(1)}%');
    context.writeln(
        'Nivel de confianza: ${(prediction.confidence * 100).toInt()}%');

    return context.toString();
  }

  String _buildPrompt(String userMessage, String context, bool hasImage) {
    final prompt = '''
Eres CalAI Coach, un coach de fitness inteligente y personalizado.
 
CONTEXTO INTEGRAL DEL USUARIO:
$context
 
MENSAJE DEL USUARIO: $userMessage
${hasImage ? 'Adjunto hay una imagen que debes analizar para dar una respuesta más precisa.' : ''}
 
INSTRUCCIONES CRÍTICAS:
1. Usa el contexto para personalizar la respuesta. No des consejos genéricos.
2. Si el usuario dice "estoy cansado", analiza el 'Recovery Status' y la 'Puntuación de Preparación'. 
   - Si la preparación es < 40, sugiere descanso total.
   - Si es 40-60, sugiere entrenamiento ligero o activo.
3. Si hay señales de sobreentrenamiento, advierte al usuario y ajusta la recomendación.
4. Proporciona pasos accionables (ej. "bebe 2 vasos de agua ahora", "reduce el peso en 5kg hoy").
5. Usa un tono profesional, motivador y empático.
 
Responde en español.
''';

    return prompt;
  }

  String _getSystemPrompt(
      FitnessMemoryProfile profile, ReadinessScore readiness) {
    return '''
Eres un coach de fitness profesional con expertise en:
- Entrenamiento de fuerza y hipertrofia
- Nutrición deportiva y suplementación
- Recuperación y prevención de lesiones
- Motivación y adherencia al entrenamiento

Tu objetivo es ayudar al usuario a alcanzar sus metas de fitness de manera segura y efectiva.

Reglas importantes:
- Nunca recomiendes ejercicios que excedan la capacidad actual del usuario
- Prioriza la forma correcta sobre el peso
- Considera la fatiga acumulada y el estado de recuperación
- Adapta las recomendaciones al nivel del usuario
- Sé específico y medible en tus recomendaciones
''';
  }

  CoachResponse _parseResponse(Map<String, dynamic>? data,
      ReadinessScore readiness, FitnessMemoryProfile profile) {
    if (data == null) {
      return _fallbackResponse(readiness);
    }

    final rawResponse = data['raw_response'] as String?;
    if (rawResponse != null) {
      return CoachResponse(
        message: rawResponse,
        type: _detectResponseType(readiness),
        suggestions: _generateSuggestions(readiness, profile),
        readinessScore: readiness.score,
      );
    }

    return _fallbackResponse(readiness);
  }

  CoachResponse _fallbackResponse(ReadinessScore readiness) {
    return CoachResponse(
      message: readiness.recommendation,
      type: CoachResponseType.advisory,
      suggestions: _generateSuggestions(readiness, null),
      readinessScore: readiness.score,
    );
  }

  CoachResponseType _detectResponseType(ReadinessScore readiness) {
    if (readiness.score < 40) return CoachResponseType.warning;
    if (readiness.score < 60) return CoachResponseType.advisory;
    return CoachResponseType.encouragement;
  }

  List<String> _generateSuggestions(
      ReadinessScore readiness, FitnessMemoryProfile? profile) {
    final suggestions = <String>[];

    if (readiness.score >= 80) {
      suggestions.add('Entrenamiento intenso autorizado');
      suggestions.add('Considera sesiones de alta intensidad');
    } else if (readiness.score >= 60) {
      suggestions.add('Entrenamiento moderado recomendado');
      suggestions.add('Evitar entrenamiento hasta el fallo');
    } else {
      suggestions.add('Priorizar descanso y recuperación');
      suggestions.add('Stretching suave o caminata ligera');
    }

    if (readiness.hydrationScore < 50) {
      suggestions.add('Aumentar hidratación');
    }

    if (readiness.recoveryScore < 50) {
      suggestions.add('Señales de fatiga detectadas');
    }

    return suggestions;
  }

  List<String> _generateFallbackSuggestions(ReadinessScore readiness) {
    if (readiness.score < 40) {
      return [
        'Descanso total o actividad ligera',
        'Prioriza dormir 7-8 horas',
        'Mantente hidratado'
      ];
    } else if (readiness.score < 60) {
      return [
        'Entrenamiento ligero',
        'Estiramientos',
        'Caminata de 30 minutos'
      ];
    } else {
      return [
        'Entrenamiento regular',
        'Mantén la consistencia',
        'Buena alimentación'
      ];
    }
  }

  Future<WorkoutRecommendation> getTodayWorkoutRecommendation() async {
    final profile = await _memoryService.getProfile();
    final readiness = await _readinessEngine.calculateReadiness(profile);
    final workoutIntel = WorkoutIntelligence(profile);

    String workoutType;
    int intensity;
    List<String> exercises;
    String rationale;

    if (readiness.score >= 80) {
      workoutType = 'Entrenamiento completo';
      intensity = 90;
      exercises = [
        'Sentadilla',
        'Press banca',
        'Peso muerto',
        'Dominadas',
        'Press militar'
      ];
      rationale = 'Tu cuerpo está listo para máxima intensidad.';
    } else if (readiness.score >= 60) {
      workoutType = 'Entrenamiento moderado';
      intensity = 70;
      exercises = [
        'Sentadilla con peso moderado',
        'Press banca',
        'Remo con barra',
        'Elevaciones laterales',
        'Curl de bíceps'
      ];
      rationale = 'Buen estado para entrenamiento estándar.';
    } else if (readiness.score >= 40) {
      workoutType = 'Entrenamiento ligero';
      intensity = 50;
      exercises = [
        'Sentadilla ligera',
        'Press banca ligero',
        'Remo con mancuernas',
        'Abdominales',
        'Estiramientos'
      ];
      rationale = 'Prioriza recuperación manteniendo movimiento.';
    } else {
      workoutType = 'Descanso activo';
      intensity = 20;
      exercises = ['Caminata', 'Estiramientos', 'Foam rolling'];
      rationale = 'Tu cuerpo necesita recuperación completa.';
    }

    return WorkoutRecommendation(
      workoutType: workoutType,
      intensity: intensity,
      suggestedExercises: exercises,
      rationale: rationale,
      readinessScore: readiness.score,
      readinessRecommendation: readiness.recommendation,
    );
  }
}

class CoachResponse {
  final String message;
  final CoachResponseType type;
  final List<String> suggestions;
  final int? readinessScore;

  CoachResponse({
    required this.message,
    required this.type,
    required this.suggestions,
    this.readinessScore,
  });
}

enum CoachResponseType {
  encouragement,
  advisory,
  warning,
  error,
}

class WorkoutRecommendation {
  final String workoutType;
  final int intensity;
  final List<String> suggestedExercises;
  final String rationale;
  final int readinessScore;
  final String readinessRecommendation;

  WorkoutRecommendation({
    required this.workoutType,
    required this.intensity,
    required this.suggestedExercises,
    required this.rationale,
    required this.readinessScore,
    required this.readinessRecommendation,
  });
}
