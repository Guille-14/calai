import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'fitness_memory_profile.dart';
import '../../../data/models/food_item.dart';
import '../../../data/services/google_fit_service.dart';
import '../../../models/workout_models.dart';

class FitnessMemoryService {
  static const String _profileKey = 'fitness_memory_profile';
  static const int _maxRecentDays = 90;

  final SharedPreferences _prefs;

  FitnessMemoryService(this._prefs);

  Future<FitnessMemoryProfile> getProfile() async {
    final json = _prefs.getString(_profileKey);
    if (json == null) return FitnessMemoryProfile.empty();
    try {
      return FitnessMemoryProfile.fromJson(jsonDecode(json));
    } catch (_) {
      return FitnessMemoryProfile.empty();
    }
  }

  Future<void> saveProfile(FitnessMemoryProfile profile) async {
    final updatedProfile = FitnessMemoryProfile(
      lastUpdated: DateTime.now(),
      recentDays: profile.recentDays,
      consistency: profile.consistency,
      nutrition: profile.nutrition,
      hydration: profile.hydration,
      recovery: profile.recovery,
      exerciseProgression: profile.exerciseProgression,
      contextualNotes: profile.contextualNotes,
    );
    await _prefs.setString(_profileKey, jsonEncode(updatedProfile.toJson()));
  }

  Future<void> updateFromFoodLog(List<FoodItem> meals, DateTime date) async {
    final profile = await getProfile();

    double totalCal = 0, totalProt = 0, totalCarb = 0, totalFat = 0;
    for (final meal in meals) {
      totalCal += meal.calories;
      totalProt += meal.protein;
      totalCarb += meal.carbs;
      totalFat += meal.fat;
    }

    final existingIndex = profile.recentDays.indexWhere(
      (d) =>
          d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day,
    );

    List<DailyFitnessRecord> updatedDays = List.from(profile.recentDays);

    DailyFitnessRecord record;
    if (existingIndex >= 0) {
      record = updatedDays[existingIndex].copyWith(
        caloriesConsumed: totalCal.toInt(),
        protein: totalProt,
        carbs: totalCarb,
        fat: totalFat,
      );
      updatedDays[existingIndex] = record;
    } else {
      record = DailyFitnessRecord(
        date: date,
        caloriesConsumed: totalCal.toInt(),
        protein: totalProt,
        carbs: totalCarb,
        fat: totalFat,
      );
      updatedDays.add(record);
    }

    if (updatedDays.length > _maxRecentDays) {
      updatedDays.sort((a, b) => b.date.compareTo(a.date));
      updatedDays = updatedDays.sublist(0, _maxRecentDays);
    }

    final newProfile = FitnessMemoryProfile(
      lastUpdated: DateTime.now(),
      recentDays: updatedDays,
      consistency: _calculateConsistency(updatedDays),
      nutrition: _calculateNutritionPattern(updatedDays),
      hydration: profile.hydration,
      recovery: profile.recovery,
      exerciseProgression: profile.exerciseProgression,
    );

    await saveProfile(newProfile);
  }

  Future<void> updateFromGoogleFit(
      GoogleFitDailyData data, DateTime date) async {
    final profile = await getProfile();

    final existingIndex = profile.recentDays.indexWhere(
      (d) =>
          d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day,
    );

    List<DailyFitnessRecord> updatedDays = List.from(profile.recentDays);

    DailyFitnessRecord record;
    if (existingIndex >= 0) {
      record = updatedDays[existingIndex].copyWith(
        steps: data.steps,
        caloriesBurned: data.activeCalories,
      );
      updatedDays[existingIndex] = record;
    } else {
      record = DailyFitnessRecord(
        date: date,
        steps: data.steps,
        caloriesBurned: data.activeCalories,
      );
      updatedDays.add(record);
    }

    if (updatedDays.length > _maxRecentDays) {
      updatedDays.sort((a, b) => b.date.compareTo(a.date));
      updatedDays = updatedDays.sublist(0, _maxRecentDays);
    }

    final newProfile = FitnessMemoryProfile(
      lastUpdated: DateTime.now(),
      recentDays: updatedDays,
      consistency: profile.consistency,
      nutrition: profile.nutrition,
      hydration: profile.hydration,
      recovery: profile.recovery,
      exerciseProgression: profile.exerciseProgression,
    );

    await saveProfile(newProfile);
  }

  Future<void> updateFromWorkout(WorkoutSession session) async {
    final profile = await getProfile();

    final date = session.date;
    final existingIndex = profile.recentDays.indexWhere(
      (d) =>
          d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day,
    );

    final muscleGroups = session.exercises.map((e) => e.name).toList();
    final volume = session.totalVolume / 1000.0;

    List<DailyFitnessRecord> updatedDays = List.from(profile.recentDays);
    final updatedProgression =
        Map<String, double>.from(profile.exerciseProgression);

    DailyFitnessRecord record;
    if (existingIndex >= 0) {
      record = updatedDays[existingIndex].copyWith(
        muscleGroupsWorked: muscleGroups,
        totalVolumeKg: volume,
        workoutDurationMinutes: session.durationMinutes,
        trainingLoad: session.durationMinutes * 0.5,
        isRestDay: false,
      );
      updatedDays[existingIndex] = record;
    } else {
      record = DailyFitnessRecord(
        date: date,
        muscleGroupsWorked: muscleGroups,
        totalVolumeKg: volume,
        workoutDurationMinutes: session.durationMinutes,
        trainingLoad: session.durationMinutes * 0.5,
        isRestDay: false,
      );
      updatedDays.add(record);
    }

    for (final exercise in session.exercises) {
      final exerciseName = exercise.name;
      final bestSet = exercise.sets
          .where((s) => s.isCompleted)
          .fold<ExerciseSet?>(null, (best, s) {
        if (best == null) return s;
        return s.weight > best.weight ? s : best;
      });

      if (bestSet != null) {
        final key = exerciseName.toLowerCase();
        final currentMax = updatedProgression[key] ?? 0;
        if (bestSet.weight > currentMax) {
          updatedProgression[key] = bestSet.weight;
        }
      }
    }

    final newProfile = FitnessMemoryProfile(
      lastUpdated: DateTime.now(),
      recentDays: updatedDays,
      consistency: _calculateConsistency(updatedDays),
      nutrition: profile.nutrition,
      hydration: profile.hydration,
      recovery: _calculateRecoveryIndicators(updatedDays),
      exerciseProgression: updatedProgression,
    );

    await saveProfile(newProfile);
  }

  Future<void> updateWaterIntake(int glasses, DateTime date) async {
    final profile = await getProfile();

    final existingIndex = profile.recentDays.indexWhere(
      (d) =>
          d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day,
    );

    List<DailyFitnessRecord> updatedDays = List.from(profile.recentDays);

    DailyFitnessRecord record;
    if (existingIndex >= 0) {
      record = updatedDays[existingIndex].copyWith(waterGlasses: glasses);
      updatedDays[existingIndex] = record;
    } else {
      record = DailyFitnessRecord(date: date, waterGlasses: glasses);
      updatedDays.add(record);
    }

    final newProfile = FitnessMemoryProfile(
      lastUpdated: DateTime.now(),
      recentDays: updatedDays,
      consistency: profile.consistency,
      nutrition: profile.nutrition,
      hydration: _calculateHydrationBehavior(updatedDays),
      recovery: profile.recovery,
      exerciseProgression: profile.exerciseProgression,
      contextualNotes: profile.contextualNotes,
    );

    await saveProfile(newProfile);
  }

  Future<String> getContextualSummary() async {
    final profile = await getProfile();
    final buffer = StringBuffer();

    buffer.writeln('USER FITNESS CONTEXT:');
    buffer.writeln('Consistency Score: ${profile.consistency.score}%');
    buffer.writeln(
        'Avg Daily Calories: ${profile.nutrition.averageCalories} kcal');
    buffer.writeln('Avg Protein: ${profile.nutrition.averageProtein}g');
    buffer.writeln('Hydration Rate: ${profile.hydration.goalAchievementRate}%');
    buffer.writeln(
        'Recovery Status: ${profile.recovery.isOvertraining ? 'Overtraining' : 'Recovering'}');
    buffer.writeln('Weekly Load: ${profile.recovery.weeklyTrainingLoad}');

    if (profile.contextualNotes.isNotEmpty) {
      buffer.writeln('AI-Observed Patterns:');
      for (final note in profile.contextualNotes) {
        buffer.writeln('- $note');
      }
    }

    return buffer.toString();
  }

  NutritionPatternSummary _calculateNutritionPattern(
      List<DailyFitnessRecord> days) {
    if (days.isEmpty) return NutritionPatternSummary.empty();

    final recent = days.take(30).toList();
    final avgCal = recent.fold<double>(0, (s, d) => s + d.caloriesConsumed) /
        recent.length;
    final avgProt =
        recent.fold<double>(0, (s, d) => s + d.protein) / recent.length;
    final avgCarb =
        recent.fold<double>(0, (s, d) => s + d.carbs) / recent.length;
    final avgFat = recent.fold<double>(0, (s, d) => s + d.fat) / recent.length;

    final totalMacroCal = (avgProt * 4) + (avgCarb * 4) + (avgFat * 9);
    final proteinPerc =
        totalMacroCal > 0 ? (avgProt * 4 / totalMacroCal) * 100 : 0.0;

    final variance = _calculateVariability(
        recent.map((d) => d.caloriesConsumed.toDouble()).toList());

    return NutritionPatternSummary(
      averageCalories: avgCal,
      averageProtein: avgProt,
      averageCarbs: avgCarb,
      averageFat: avgFat,
      proteinPercentage: proteinPerc,
      mealsPerDay: 3,
      calorieVariability: variance,
    );
  }

  TrainingConsistencyScore _calculateConsistency(
      List<DailyFitnessRecord> days) {
    if (days.isEmpty) return TrainingConsistencyScore.empty();

    final now = DateTime.now();
    final last30 =
        days.where((d) => now.difference(d.date).inDays <= 30).toList();
    final daysActive = last30.where((d) => d.workoutDurationMinutes > 0).length;
    final workouts = last30.where((d) => d.workoutDurationMinutes > 0).toList();
    final avgDuration = workouts.isEmpty
        ? 0.0
        : workouts.fold<double>(0, (s, d) => s + d.workoutDurationMinutes) /
            workouts.length;

    final score = (daysActive / 30) * 100;
    final weeklyFreq = (daysActive / 4).clamp(0.0, 7.0);

    return TrainingConsistencyScore(
      score: score,
      daysActive: daysActive,
      totalDays: 30,
      weeklyFrequency: weeklyFreq,
      averageWorkoutDuration: avgDuration,
      completedWorkouts: workouts.map((d) => d.date).toList(),
    );
  }

  HydrationBehavior _calculateHydrationBehavior(List<DailyFitnessRecord> days) {
    if (days.isEmpty) return HydrationBehavior.empty();

    final recent = days.take(7).toList();
    final avgGlasses =
        recent.fold<double>(0, (s, d) => s + d.waterGlasses) / recent.length;
    final goalMet = recent.where((d) => d.waterGlasses >= 8).length;
    final rate = goalMet / recent.length;

    return HydrationBehavior(
      averageGlasses: avgGlasses,
      daysGoalMet: goalMet,
      totalDays: recent.length,
      goalAchievementRate: rate * 100,
      peakHour: 12,
    );
  }

  RecoveryIndicators _calculateRecoveryIndicators(
      List<DailyFitnessRecord> days) {
    if (days.isEmpty) return RecoveryIndicators.empty();

    final recent = days.take(7).toList();
    final weeklyLoad =
        recent.fold<double>(0, (s, d) => s + (d.trainingLoad ?? 0));
    final weeklyVol = recent.fold<double>(0, (s, d) => s + d.totalVolumeKg);

    final highLoadDays = recent.where((d) => (d.trainingLoad ?? 0) > 80).length;
    final isOvertraining = highLoadDays >= 4 && weeklyLoad > 400;

    return RecoveryIndicators(
      averageSleepHours: 7,
      averageRestingHeartRate: null,
      weeklyTrainingLoad: weeklyLoad,
      weeklyVolume: weeklyVol,
      consecutiveHighLoadDays: highLoadDays,
      isOvertraining: isOvertraining,
    );
  }

  double _calculateVariability(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    return variance > 0 ? (sqrt(variance) / mean) * 100 : 0;
  }
}
