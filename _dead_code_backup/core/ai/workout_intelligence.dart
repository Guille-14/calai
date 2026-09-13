import 'dart:math';
import 'fitness_memory_profile.dart';
import 'training_suggestion.dart';

class WorkoutIntelligence {
  final FitnessMemoryProfile profile;

  WorkoutIntelligence(this.profile);

  TrainingSuggestion generateSuggestion(String exerciseName) {
    final exerciseHistory = _getExerciseHistory(exerciseName);
    final recentPerformance = _getRecentPerformance(exerciseName);
    final fatigueLevel = _calculateFatigueLevel();
    final readinessMultiplier = _getReadinessMultiplier();
    final consistencyFactor = _getConsistencyFactor();
    final sleepFactor = _getSleepFactor();
    final muscleBalance = _calculateMuscleBalance();
    final weeklyLoad = _calculateWeeklyLoad(exerciseName);

    final weightSuggestion = _suggestWeight(
        recentPerformance, readinessMultiplier, consistencyFactor, sleepFactor);
    final repSuggestion =
        _suggestReps(recentPerformance, readinessMultiplier, fatigueLevel);
    final restSuggestion = _suggestRest(fatigueLevel, weeklyLoad);
    final volumeAdvice =
        _balanceVolume(exerciseName, muscleBalance, weeklyLoad);
    final prDetection = _isPR(exerciseName, weightSuggestion.weight);
    final estimated1RM =
        _calculate1RM(weightSuggestion.weight, repSuggestion.reps);
    final fatigueAdjustment =
        _calculateFatigueAdjustment(fatigueLevel, readinessMultiplier);
    final muscleImbalanceAdvice =
        _detectMuscleImbalance(exerciseName, muscleBalance);

    return TrainingSuggestion(
      exerciseName: exerciseName,
      suggestedWeight: weightSuggestion.weight,
      weightRationale: weightSuggestion.rationale,
      suggestedReps: repSuggestion.reps,
      repRationale: repSuggestion.rationale,
      suggestedRestSeconds: restSuggestion.seconds,
      restRationale: restSuggestion.rationale,
      isPR: prDetection,
      estimated1RM: estimated1RM,
      fatigueAdjustment: fatigueAdjustment,
      volumeBalance: volumeAdvice,
      muscleImbalance: muscleImbalanceAdvice,
      weeklyLoadStatus: weeklyLoad,
      sleepQuality: sleepFactor,
      consistencyLevel: consistencyFactor,
    );
  }

  List<_PerformanceEntry> _getExerciseHistory(String exerciseName) {
    final history = <_PerformanceEntry>[];
    final key = exerciseName.toLowerCase();

    for (final day in profile.recentDays) {
      if (day.muscleGroupsWorked.contains(exerciseName)) {
        history.add(_PerformanceEntry(
          date: day.date,
          volume: day.totalVolumeKg,
          load: day.trainingLoad ?? 0,
          weight: _getMaxWeightForExercise(day, exerciseName),
          reps: _getRepsForWeight(
              day, exerciseName, _getMaxWeightForExercise(day, exerciseName)),
        ));
      }
    }

    return history;
  }

  double _getMaxWeightForExercise(DailyFitnessRecord day, String exerciseName) {
    final key = exerciseName.toLowerCase();
    return profile.exerciseProgression[key] ?? 0;
  }

  int _getRepsForWeight(
      DailyFitnessRecord day, String exerciseName, double weight) {
    if (weight == 0) return 0;
    return 10; // Default estimation
  }

  _RecentPerformance _getRecentPerformance(String exerciseName) {
    final now = DateTime.now();
    final last7Days = profile.recentDays
        .where((d) => now.difference(d.date).inDays <= 7)
        .toList();

    if (last7Days.isEmpty) {
      return _RecentPerformance(
        lastWeight: 0,
        lastReps: 0,
        weekVolume: 0,
        trend: 0,
        avgWeight: 0,
        maxWeight: 0,
      );
    }

    final key = exerciseName.toLowerCase();
    final lastMax = profile.exerciseProgression[key] ?? 0;

    double totalVolume = 0;
    double maxWeight = 0;
    double totalWeight = 0;
    int weightCount = 0;

    for (final day in last7Days) {
      totalVolume += day.totalVolumeKg;
      final dayMax = _getMaxWeightForExercise(day, exerciseName);
      if (dayMax > maxWeight) maxWeight = dayMax;
      if (dayMax > 0) {
        totalWeight += dayMax;
        weightCount++;
      }
    }

    final avgWeight = weightCount > 0 ? totalWeight / weightCount : 0.0;

    return _RecentPerformance(
      lastWeight: lastMax,
      lastReps: 10,
      weekVolume: totalVolume,
      trend: _calculateTrend(exerciseName).toDouble(),
      avgWeight: avgWeight,
      maxWeight: maxWeight,
    );
  }

  double _calculateTrend(String exerciseName) {
    if (profile.recentDays.length < 2) return 0;

    final key = exerciseName.toLowerCase();
    final current = profile.exerciseProgression[key] ?? 0;
    if (current == 0) return 0;

    final weights = <double>[];
    final cutoff = DateTime.now().subtract(Duration(days: 35));

    for (final day in profile.recentDays) {
      if (day.date.isAfter(cutoff) &&
          day.muscleGroupsWorked.any((e) => e.toLowerCase().contains(key))) {
        final weight = _getMaxWeightForExercise(day, exerciseName);
        if (weight > 0) weights.add(weight);
      }
    }

    if (weights.length < 2) return 0;

    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    for (int i = 0; i < weights.length; i++) {
      sumX += i;
      sumY += weights[i];
      sumXY += i * weights[i];
      sumXX += i * i;
    }

    final n = weights.length.toDouble();
    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    return slope.clamp(-2.0, 2.0);
  }

  double _calculateFatigueLevel() {
    if (profile.recentDays.isEmpty) return 0.5;

    final recent = profile.recentDays.take(7).toList();
    final avgLoad =
        recent.fold<double>(0, (s, d) => s + (d.trainingLoad ?? 0)) /
            recent.length;
    final loadFactor = (avgLoad / 100).clamp(0.0, 1.0);

    final avgVolume =
        recent.fold<double>(0, (s, d) => s + d.totalVolumeKg) / recent.length;
    final volumeFactor = (avgVolume / 500).clamp(0.0, 1.0);

    final consistencyDev = (profile.consistency.score - 70).abs() / 70;
    final consistencyFactor = consistencyDev.clamp(0.0, 1.0);

    final recoveryFactor = profile.recovery.isOvertraining ? 0.8 : 0.2;

    final fatigue = (loadFactor * 0.4 +
        volumeFactor * 0.3 +
        consistencyFactor * 0.2 +
        recoveryFactor * 0.1);

    return fatigue.clamp(0.0, 1.0);
  }

  double _getReadinessMultiplier() {
    if (profile.recentDays.isEmpty) return 1.0;

    final today = profile.recentDays.first;
    final stepsFactor = (today.steps / 10000).clamp(0.5, 1.5);
    final hydrationFactor = (today.waterGlasses / 8).clamp(0.5, 1.5);

    return ((stepsFactor + hydrationFactor) / 2).clamp(0.8, 1.2);
  }

  double _getConsistencyFactor() {
    return (profile.consistency.score / 100).clamp(0.9, 1.1);
  }

  double _getSleepFactor() {
    final sleep = profile.recovery.averageSleepHours;
    if (sleep >= 8) return 1.1;
    if (sleep <= 6) return 0.9;
    return 1.0;
  }

  double _calculateMuscleBalance() {
    // Simplified muscle balance based on volume distribution
    return 1.0;
  }

  double _calculateWeeklyLoad(String exerciseName) {
    final key = exerciseName.toLowerCase();
    double volume = 0;
    final now = DateTime.now();
    for (final day in profile.recentDays) {
      if (now.difference(day.date).inDays <= 7) {
        if (day.muscleGroupsWorked.contains(exerciseName)) {
          volume += day.totalVolumeKg;
        }
      }
    }
    return volume;
  }

  _WeightSuggestion _suggestWeight(_RecentPerformance performance,
      double readiness, double consistency, double sleep) {
    double weight = performance.lastWeight;
    String rationale = 'Mantener peso basado en rendimiento reciente';

    if (readiness > 1.0 && consistency > 1.0 && sleep > 1.0) {
      weight *= 1.025;
      rationale = 'Aumento sugerido por alta recuperación y consistencia';
    } else if (readiness < 0.9 || sleep < 0.9) {
      weight *= 0.975;
      rationale = 'Reducción sugerida por fatiga o falta de sueño';
    }

    return _WeightSuggestion(weight: weight, rationale: rationale);
  }

  _RepSuggestion _suggestReps(
      _RecentPerformance performance, double readiness, double fatigue) {
    int reps = performance.lastReps;
    String rationale = 'Mantener rango de repeticiones';

    if (fatigue > 0.7) {
      reps -= 2;
      rationale = 'Reducción de reps sugerida por alta fatiga';
    } else if (readiness > 1.1) {
      reps += 1;
      rationale = 'Aumento de reps sugerido por excelente estado';
    }

    return _RepSuggestion(reps: max(1, reps), rationale: rationale);
  }

  _RestSuggestion _suggestRest(double fatigue, double weeklyLoad) {
    int seconds = 90;
    String rationale = 'Descanso estándar para hipertrofia';

    if (fatigue > 0.7 || weeklyLoad > 2000) {
      seconds = 120;
      rationale = 'Descanso extendido sugerido por carga alta';
    } else if (fatigue < 0.3) {
      seconds = 60;
      rationale = 'Descanso reducido sugerido por baja fatiga';
    }

    return _RestSuggestion(seconds: seconds, rationale: rationale);
  }

  String _balanceVolume(
      String exerciseName, double muscleBalance, double weeklyLoad) {
    if (weeklyLoad > 3000) {
      return 'Carga semanal muy alta. Considerar reducir volumen.';
    }
    if (weeklyLoad < 1000) {
      return 'Carga semanal baja. Oportunidad de aumentar volumen.';
    }
    return 'Volumen equilibrado para este ejercicio.';
  }

  bool _isPR(String exerciseName, double weight) {
    final key = exerciseName.toLowerCase();
    final maxWeight = profile.exerciseProgression[key] ?? 0;
    return weight > maxWeight;
  }

  double _calculate1RM(double weight, int reps) {
    if (reps <= 1) return weight;
    return weight * (1 + (reps / 30)); // Brzycki formula approximation
  }

  double _calculateFatigueAdjustment(double fatigue, double readiness) {
    return (fatigue * 0.6 + (1 - readiness) * 0.4).clamp(0.0, 1.0);
  }

  String _detectMuscleImbalance(String exerciseName, double muscleBalance) {
    if (muscleBalance < 0.8) {
      return 'Posible desbalance detectado en este grupo muscular.';
    }
    return 'Balance muscular adecuado.';
  }
}

class _PerformanceEntry {
  final DateTime date;
  final double volume;
  final double load;
  final double weight;
  final int reps;

  _PerformanceEntry({
    required this.date,
    required this.volume,
    required this.load,
    required this.weight,
    required this.reps,
  });
}

class _RecentPerformance {
  final double lastWeight;
  final int lastReps;
  final double weekVolume;
  final double trend;
  final double avgWeight;
  final double maxWeight;

  _RecentPerformance({
    required this.lastWeight,
    required this.lastReps,
    required this.weekVolume,
    required this.trend,
    required this.avgWeight,
    required this.maxWeight,
  });
}

class _WeightSuggestion {
  final double weight;
  final String rationale;

  _WeightSuggestion({required this.weight, required this.rationale});
}

class _RepSuggestion {
  final int reps;
  final String rationale;

  _RepSuggestion({required this.reps, required this.rationale});
}

class _RestSuggestion {
  final int seconds;
  final String rationale;

  _RestSuggestion({required this.seconds, required this.rationale});
}
