import 'dart:math';
import 'fitness_memory_profile.dart';

class ReadinessScore {
  final int score;
  final int stepsScore;
  final int caloriesScore;
  final int hydrationScore;
  final int sleepScore;
  final int consistencyScore;
  final int recoveryScore;
  final String recommendation;
  final List<String> factors;

  ReadinessScore({
    required this.score,
    required this.stepsScore,
    required this.caloriesScore,
    required this.hydrationScore,
    required this.sleepScore,
    required this.consistencyScore,
    required this.recoveryScore,
    required this.recommendation,
    required this.factors,
  });

  factory ReadinessScore.empty() {
    return ReadinessScore(
      score: 50,
      stepsScore: 50,
      caloriesScore: 50,
      hydrationScore: 50,
      sleepScore: 50,
      consistencyScore: 50,
      recoveryScore: 50,
      recommendation: 'Sin datos suficientes para calcular',
      factors: [],
    );
  }
}

class ReadinessEngine {
  static const int _stepsGoal = 10000;
  static const int _caloriesBurnedGoal = 500;
  static const int _waterGoal = 8;
  static const double _sleepGoal = 7.5;
  static const double _maxTrainingLoad = 100;

  Future<ReadinessScore> calculateReadiness(
      FitnessMemoryProfile profile) async {
    if (profile.recentDays.isEmpty) {
      return ReadinessScore.empty();
    }

    final today = profile.recentDays.firstWhere(
      (d) =>
          d.date.year == DateTime.now().year &&
          d.date.month == DateTime.now().month &&
          d.date.day == DateTime.now().day,
      orElse: () => DailyFitnessRecord(date: DateTime.now()),
    );

    final stepsScore = _calculateStepsScore(today.steps);
    final caloriesScore = _calculateCaloriesScore(today.caloriesBurned);
    final hydrationScore = _calculateHydrationScore(today.waterGlasses);
    final sleepScore = _calculateSleepScore(today.sleepHours);
    final consistencyScore = _calculateConsistencyScore(profile.consistency);
    final recoveryScore = _calculateRecoveryScore(profile.recovery);

    final weights = {
      'steps': 0.10,
      'calories': 0.10,
      'hydration': 0.15,
      'sleep': 0.30,
      'consistency': 0.15,
      'recovery': 0.20
    };

    final totalScore = (stepsScore * weights['steps']! +
            caloriesScore * weights['calories']! +
            hydrationScore * weights['hydration']! +
            sleepScore * weights['sleep']! +
            consistencyScore * weights['consistency']! +
            recoveryScore * weights['recovery']!)
        .round();

    final recommendation =
        _generateRecommendation(totalScore, today, profile.recovery);
    final factors = _collectFactors(stepsScore, caloriesScore, hydrationScore,
        sleepScore, consistencyScore, recoveryScore);

    return ReadinessScore(
      score: totalScore,
      stepsScore: stepsScore,
      caloriesScore: caloriesScore,
      hydrationScore: hydrationScore,
      sleepScore: sleepScore,
      consistencyScore: consistencyScore,
      recoveryScore: recoveryScore,
      recommendation: recommendation,
      factors: factors,
    );
  }

  int _calculateStepsScore(int steps) {
    if (steps >= _stepsGoal) return 100;
    if (steps <= 0) return 0;
    return min(100, (steps / _stepsGoal * 100).round());
  }

  int _calculateCaloriesScore(int calories) {
    if (calories >= _caloriesBurnedGoal) return 100;
    if (calories <= 0) return 0;
    return min(100, (calories / _caloriesBurnedGoal * 100).round());
  }

  int _calculateHydrationScore(int glasses) {
    if (glasses >= _waterGoal) return 100;
    if (glasses <= 0) return 0;
    return min(100, (glasses / _waterGoal * 100).round());
  }

  int _calculateSleepScore(int? hours) {
    if (hours == null) return 50;
    if (hours >= _sleepGoal) return 100;
    if (hours <= 0) return 0;
    return min(100, (hours / _sleepGoal * 100).round());
  }

  int _calculateConsistencyScore(TrainingConsistencyScore consistency) {
    return min(100, consistency.score.round());
  }

  int _calculateRecoveryScore(RecoveryIndicators recovery) {
    if (recovery.isOvertraining) return 30;
    if (recovery.consecutiveHighLoadDays >= 3) return 50;
    if (recovery.weeklyTrainingLoad > _maxTrainingLoad * 0.8) return 60;
    return 80;
  }

  String _generateRecommendation(
      int score, DailyFitnessRecord today, RecoveryIndicators recovery) {
    if (score >= 80) {
      return '¡Excelente! Estás listo para un entrenamiento intenso. Tu cuerpo está bien recuperado.';
    } else if (score >= 60) {
      return 'Buen estado general. Un entrenamiento moderado es apropiado hoy.';
    } else if (score >= 40) {
      if (recovery.isOvertraining) {
        return 'Señales de sobreentrenamiento. Considera un día de descanso o entrenamiento ligero.';
      }
      return 'Fatiga acumulada detectada. Recomendamos un entrenamiento ligero o activo recovery.';
    } else {
      return 'Tu cuerpo necesita descanso. Prioriza la recuperación hoy.';
    }
  }

  List<String> _collectFactors(int steps, int calories, int hydration,
      int sleep, int consistency, int recovery) {
    final factors = <String>[];

    if (steps >= 80) factors.add('✓ Pasos adecuados');
    if (steps < 50) factors.add('⚠ Pasos por debajo del objetivo');

    if (hydration >= 80) factors.add('✓ Hidratación correcta');
    if (hydration < 50) factors.add('⚠ Hidratación insuficiente');

    if (sleep >= 80) factors.add('✓ Sueño adecuado');
    if (sleep < 50) factors.add('⚠ Sueño insuficiente');

    if (recovery < 50) factors.add('⚠ Señales de fatiga');

    return factors;
  }
}
