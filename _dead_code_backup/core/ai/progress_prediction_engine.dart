import 'fitness_memory_profile.dart';

class ProgressPrediction {
  final double muscleGainEstimate;
  final double fatLossEstimate;
  final double strengthProgress;
  final String timeline;
  final List<PredictionPoint> curve;
  final double confidence;

  ProgressPrediction({
    required this.muscleGainEstimate,
    required this.fatLossEstimate,
    required this.strengthProgress,
    required this.timeline,
    required this.curve,
    required this.confidence,
  });
}

class PredictionPoint {
  final DateTime date;
  final double value;
  final String label;

  PredictionPoint(
      {required this.date, required this.value, required this.label});
}

class ProgressPredictionEngine {
  Future<ProgressPrediction> predict(FitnessMemoryProfile profile) async {
    if (profile.recentDays.length < 7) {
      return _insufficientDataPrediction();
    }

    final muscleGain = _predictMuscleGain(profile);
    final fatLoss = _predictFatLoss(profile);
    final strength = _predictStrengthProgress(profile);
    final curve = _generateCurve(profile, muscleGain, fatLoss);
    final confidence = _calculateConfidence(profile.recentDays.length);

    final timeline = _generateTimeline(muscleGain, fatLoss);

    return ProgressPrediction(
      muscleGainEstimate: muscleGain,
      fatLossEstimate: fatLoss,
      strengthProgress: strength,
      timeline: timeline,
      curve: curve,
      confidence: confidence,
    );
  }

  ProgressPrediction predictHypothetical(FitnessMemoryProfile profile,
      {double? extraProtein, int? extraWorkouts}) {
    // Create a hypothetical profile
    final hypotheticalProfile = FitnessMemoryProfile(
      lastUpdated: profile.lastUpdated,
      recentDays: profile.recentDays,
      consistency: profile.consistency,
      nutrition: NutritionPatternSummary(
        averageCalories: profile.nutrition.averageCalories,
        averageProtein: profile.nutrition.averageProtein + (extraProtein ?? 0),
        averageCarbs: profile.nutrition.averageCarbs,
        averageFat: profile.nutrition.averageFat,
        proteinPercentage: profile.nutrition.proteinPercentage,
        mealsPerDay: profile.nutrition.mealsPerDay,
        calorieVariability: profile.nutrition.calorieVariability,
      ),
      hydration: profile.hydration,
      recovery: profile.recovery,
      exerciseProgression: profile.exerciseProgression,
    );

    // Simple adjustment for extra workouts in a simplified way for hypothetical
    // We simulate more active days by adding to the profile.recentDays (conceptual)

    final muscleGain = _predictMuscleGain(hypotheticalProfile);
    final fatLoss = _predictFatLoss(hypotheticalProfile);
    final strength = _predictStrengthProgress(hypotheticalProfile);
    final curve = _generateCurve(hypotheticalProfile, muscleGain, fatLoss);
    final confidence = _calculateConfidence(profile.recentDays.length);
    final timeline = _generateTimeline(muscleGain, fatLoss);

    return ProgressPrediction(
      muscleGainEstimate: muscleGain,
      fatLossEstimate: fatLoss,
      strengthProgress: strength,
      timeline: timeline,
      curve: curve,
      confidence: confidence,
    );
  }

  ProgressPrediction _insufficientDataPrediction() {
    return ProgressPrediction(
      muscleGainEstimate: 0,
      fatLossEstimate: 0,
      strengthProgress: 0,
      timeline: 'Recopila más datos para generar predicciones precisas.',
      curve: [],
      confidence: 0,
    );
  }

  double _predictMuscleGain(FitnessMemoryProfile profile) {
    final activeDays =
        profile.recentDays.where((d) => d.workoutDurationMinutes > 30).length;
    final avgProtein = profile.nutrition.averageProtein;
    final weeklyWorkouts = activeDays / 4;

    // Volume trend factor
    double volumeTrend = 0;
    if (profile.recentDays.length >= 14) {
      final firstHalf = profile.recentDays
          .take(7)
          .fold<double>(0, (s, d) => s + d.totalVolumeKg);
      final secondHalf = profile.recentDays
          .skip(7)
          .take(7)
          .fold<double>(0, (s, d) => s + d.totalVolumeKg);
      volumeTrend = (secondHalf - firstHalf) / (firstHalf > 0 ? firstHalf : 1);
    }

    double monthlyGain = 0;

    if (avgProtein >= 150) {
      monthlyGain += 0.5;
    } else if (avgProtein >= 100) {
      monthlyGain += 0.3;
    } else {
      monthlyGain += 0.1;
    }

    if (weeklyWorkouts >= 4) {
      monthlyGain += 0.3;
    } else if (weeklyWorkouts >= 2) {
      monthlyGain += 0.2;
    }

    monthlyGain += volumeTrend * 0.1;

    if (profile.consistency.score > 80) {
      monthlyGain += 0.2;
    }

    return monthlyGain.clamp(0, 1.5);
  }

  double _predictFatLoss(FitnessMemoryProfile profile) {
    final avgCaloricBalance = profile.nutrition.averageCalories -
        (profile.consistency.score > 50 ? 500 : 300);
    final hydrationRate = profile.hydration.goalAchievementRate / 100;

    double monthlyLoss = 0;

    if (avgCaloricBalance < -300) {
      monthlyLoss += 1.5;
    } else if (avgCaloricBalance < 0) {
      monthlyLoss += 0.5;
    }

    if (hydrationRate > 0.7) {
      monthlyLoss += 0.3;
    }

    if (profile.recentDays.any((d) => d.steps > 8000)) {
      monthlyLoss += 0.2;
    }

    return monthlyLoss.clamp(0, 3.0);
  }

  double _predictStrengthProgress(FitnessMemoryProfile profile) {
    final exerciseCount = profile.exerciseProgression.length;
    if (exerciseCount == 0) return 0;

    double totalProgress = 0;
    for (final entry in profile.exerciseProgression.entries) {
      final recent = profile.recentDays.take(14).where((d) =>
          d.muscleGroupsWorked.any((m) => m.toLowerCase().contains(entry.key)));
      if (recent.isNotEmpty) {
        totalProgress += entry.value * 0.02;
      }
    }

    return (totalProgress / exerciseCount).clamp(0, 10);
  }

  List<PredictionPoint> _generateCurve(
      FitnessMemoryProfile profile, double muscleGain, double fatLoss) {
    final curve = <PredictionPoint>[];
    final now = DateTime.now();

    for (int i = 0; i <= 12; i++) {
      final date = now.add(Duration(days: i * 30));
      final muscleProgress = muscleGain * (i + 1);
      final fatProgress = -fatLoss * (i + 1);

      curve.add(PredictionPoint(
        date: date,
        value: muscleProgress,
        label: 'Mes ${i + 1}',
      ));
    }

    return curve;
  }

  double _calculateConfidence(int daysCount) {
    if (daysCount >= 90) return 0.9;
    if (daysCount >= 60) return 0.75;
    if (daysCount >= 30) return 0.6;
    if (daysCount >= 14) return 0.4;
    return 0.2;
  }

  String _generateTimeline(double muscleGain, double fatLoss) {
    final months = (1 / (muscleGain > 0 ? muscleGain : 0.5)).ceil();

    String timeline = 'Basado en tus patrones actuales:\n';

    if (muscleGain > 0) {
      timeline +=
          '• Ganancia muscular estimada: ${muscleGain.toStringAsFixed(1)}kg/mes\n';
    }

    if (fatLoss > 0) {
      timeline +=
          '• Pérdida de grasa estimada: ${fatLoss.toStringAsFixed(1)}kg/mes\n';
    }

    timeline += '\nMantén consistencia para optimizar resultados.';

    return timeline;
  }
}
