
class FitnessMemoryProfile {
  static const String _keyPrefix = 'fitness_memory_';

  final DateTime lastUpdated;
  final List<DailyFitnessRecord> recentDays;
  final TrainingConsistencyScore consistency;
  final NutritionPatternSummary nutrition;
  final HydrationBehavior hydration;
  final RecoveryIndicators recovery;
  final Map<String, double> exerciseProgression;
  final List<String> contextualNotes;

  FitnessMemoryProfile({
    required this.lastUpdated,
    required this.recentDays,
    required this.consistency,
    required this.nutrition,
    required this.hydration,
    required this.recovery,
    required this.exerciseProgression,
    this.contextualNotes = const [],
  });

  factory FitnessMemoryProfile.empty() {
    return FitnessMemoryProfile(
      lastUpdated: DateTime.now(),
      recentDays: [],
      consistency: TrainingConsistencyScore.empty(),
      nutrition: NutritionPatternSummary.empty(),
      hydration: HydrationBehavior.empty(),
      recovery: RecoveryIndicators.empty(),
      exerciseProgression: {},
      contextualNotes: [],
    );
  }

  Map<String, dynamic> toJson() => {
        'lastUpdated': lastUpdated.toIso8601String(),
        'recentDays': recentDays.map((d) => d.toJson()).toList(),
        'consistency': consistency.toJson(),
        'nutrition': nutrition.toJson(),
        'hydration': hydration.toJson(),
        'recovery': recovery.toJson(),
        'exerciseProgression': exerciseProgression,
        'contextualNotes': contextualNotes,
      };

  factory FitnessMemoryProfile.fromJson(Map<String, dynamic> json) {
    return FitnessMemoryProfile(
      lastUpdated: DateTime.parse(json['lastUpdated']),
      recentDays: (json['recentDays'] as List)
          .map((d) => DailyFitnessRecord.fromJson(d))
          .toList(),
      consistency: TrainingConsistencyScore.fromJson(json['consistency']),
      nutrition: NutritionPatternSummary.fromJson(json['nutrition']),
      hydration: HydrationBehavior.fromJson(json['hydration']),
      recovery: RecoveryIndicators.fromJson(json['recovery']),
      exerciseProgression:
          Map<String, double>.from(json['exerciseProgression']),
      contextualNotes: List<String>.from(json['contextualNotes'] ?? []),
    );
  }
}

class DailyFitnessRecord {
  final DateTime date;
  final int steps;
  final int caloriesBurned;
  final int caloriesConsumed;
  final double protein;
  final double carbs;
  final double fat;
  final int waterGlasses;
  final int? sleepHours;
  final int? restingHeartRate;
  final double? trainingLoad;
  final List<String> muscleGroupsWorked;
  final double totalVolumeKg;
  final int workoutDurationMinutes;
  final bool isRestDay;

  DailyFitnessRecord({
    required this.date,
    this.steps = 0,
    this.caloriesBurned = 0,
    this.caloriesConsumed = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.waterGlasses = 0,
    this.sleepHours,
    this.restingHeartRate,
    this.trainingLoad,
    this.muscleGroupsWorked = const [],
    this.totalVolumeKg = 0,
    this.workoutDurationMinutes = 0,
    this.isRestDay = false,
  });

  double get getCalorieBalance =>
      (caloriesConsumed - caloriesBurned).toDouble();
  double get getMacroRatio =>
      protein > 0 ? (protein * 4) / ((carbs * 4) + (fat * 9)) : 0;

  DailyFitnessRecord copyWith({
    DateTime? date,
    int? steps,
    int? caloriesBurned,
    int? caloriesConsumed,
    double? protein,
    double? carbs,
    double? fat,
    int? waterGlasses,
    int? sleepHours,
    int? restingHeartRate,
    double? trainingLoad,
    List<String>? muscleGroupsWorked,
    double? totalVolumeKg,
    int? workoutDurationMinutes,
    bool? isRestDay,
  }) {
    return DailyFitnessRecord(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      caloriesConsumed: caloriesConsumed ?? this.caloriesConsumed,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      waterGlasses: waterGlasses ?? this.waterGlasses,
      sleepHours: sleepHours ?? this.sleepHours,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      trainingLoad: trainingLoad ?? this.trainingLoad,
      muscleGroupsWorked: muscleGroupsWorked ?? this.muscleGroupsWorked,
      totalVolumeKg: totalVolumeKg ?? this.totalVolumeKg,
      workoutDurationMinutes:
          workoutDurationMinutes ?? this.workoutDurationMinutes,
      isRestDay: isRestDay ?? this.isRestDay,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'steps': steps,
        'caloriesBurned': caloriesBurned,
        'caloriesConsumed': caloriesConsumed,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'waterGlasses': waterGlasses,
        'sleepHours': sleepHours,
        'restingHeartRate': restingHeartRate,
        'trainingLoad': trainingLoad,
        'muscleGroupsWorked': muscleGroupsWorked,
        'totalVolumeKg': totalVolumeKg,
        'workoutDurationMinutes': workoutDurationMinutes,
        'isRestDay': isRestDay,
      };

  factory DailyFitnessRecord.fromJson(Map<String, dynamic> json) {
    return DailyFitnessRecord(
      date: DateTime.parse(json['date']),
      steps: json['steps'] ?? 0,
      caloriesBurned: json['caloriesBurned'] ?? 0,
      caloriesConsumed: json['caloriesConsumed'] ?? 0,
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      waterGlasses: json['waterGlasses'] ?? 0,
      sleepHours: json['sleepHours'],
      restingHeartRate: json['restingHeartRate'],
      trainingLoad: json['trainingLoad']?.toDouble(),
      muscleGroupsWorked: List<String>.from(json['muscleGroupsWorked'] ?? []),
      totalVolumeKg: (json['totalVolumeKg'] ?? 0).toDouble(),
      workoutDurationMinutes: json['workoutDurationMinutes'] ?? 0,
      isRestDay: json['isRestDay'] ?? false,
    );
  }
}

class TrainingConsistencyScore {
  final double score;
  final int daysActive;
  final int totalDays;
  final double weeklyFrequency;
  final double averageWorkoutDuration;
  final List<DateTime> missedWorkouts;
  final List<DateTime> completedWorkouts;

  TrainingConsistencyScore({
    required this.score,
    required this.daysActive,
    required this.totalDays,
    required this.weeklyFrequency,
    required this.averageWorkoutDuration,
    this.missedWorkouts = const [],
    this.completedWorkouts = const [],
  });

  factory TrainingConsistencyScore.empty() {
    return TrainingConsistencyScore(
      score: 0,
      daysActive: 0,
      totalDays: 1,
      weeklyFrequency: 0,
      averageWorkoutDuration: 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'daysActive': daysActive,
        'totalDays': totalDays,
        'weeklyFrequency': weeklyFrequency,
        'averageWorkoutDuration': averageWorkoutDuration,
        'missedWorkouts':
            missedWorkouts.map((d) => d.toIso8601String()).toList(),
        'completedWorkouts':
            completedWorkouts.map((d) => d.toIso8601String()).toList(),
      };

  factory TrainingConsistencyScore.fromJson(Map<String, dynamic> json) {
    return TrainingConsistencyScore(
      score: (json['score'] ?? 0).toDouble(),
      daysActive: json['daysActive'] ?? 0,
      totalDays: json['totalDays'] ?? 1,
      weeklyFrequency: (json['weeklyFrequency'] ?? 0).toDouble(),
      averageWorkoutDuration: (json['averageWorkoutDuration'] ?? 0).toDouble(),
      missedWorkouts: (json['missedWorkouts'] as List?)
              ?.map((d) => DateTime.parse(d))
              .toList() ??
          [],
      completedWorkouts: (json['completedWorkouts'] as List?)
              ?.map((d) => DateTime.parse(d))
              .toList() ??
          [],
    );
  }
}

class NutritionPatternSummary {
  final double averageCalories;
  final double averageProtein;
  final double averageCarbs;
  final double averageFat;
  final double proteinPercentage;
  final int mealsPerDay;
  final List<String> commonFoods;
  final double calorieVariability;

  NutritionPatternSummary({
    required this.averageCalories,
    required this.averageProtein,
    required this.averageCarbs,
    required this.averageFat,
    required this.proteinPercentage,
    required this.mealsPerDay,
    this.commonFoods = const [],
    required this.calorieVariability,
  });

  factory NutritionPatternSummary.empty() {
    return NutritionPatternSummary(
      averageCalories: 0,
      averageProtein: 0,
      averageCarbs: 0,
      averageFat: 0,
      proteinPercentage: 0,
      mealsPerDay: 0,
      calorieVariability: 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'averageCalories': averageCalories,
        'averageProtein': averageProtein,
        'averageCarbs': averageCarbs,
        'averageFat': averageFat,
        'proteinPercentage': proteinPercentage,
        'mealsPerDay': mealsPerDay,
        'commonFoods': commonFoods,
        'calorieVariability': calorieVariability,
      };

  factory NutritionPatternSummary.fromJson(Map<String, dynamic> json) {
    return NutritionPatternSummary(
      averageCalories: (json['averageCalories'] ?? 0).toDouble(),
      averageProtein: (json['averageProtein'] ?? 0).toDouble(),
      averageCarbs: (json['averageCarbs'] ?? 0).toDouble(),
      averageFat: (json['averageFat'] ?? 0).toDouble(),
      proteinPercentage: (json['proteinPercentage'] ?? 0).toDouble(),
      mealsPerDay: json['mealsPerDay'] ?? 0,
      commonFoods: List<String>.from(json['commonFoods'] ?? []),
      calorieVariability: (json['calorieVariability'] ?? 0).toDouble(),
    );
  }
}

class HydrationBehavior {
  final double averageGlasses;
  final int daysGoalMet;
  final int totalDays;
  final double goalAchievementRate;
  final int peakHour;
  final List<int> hourlyDistribution;

  HydrationBehavior({
    required this.averageGlasses,
    required this.daysGoalMet,
    required this.totalDays,
    required this.goalAchievementRate,
    required this.peakHour,
    this.hourlyDistribution = const [],
  });

  factory HydrationBehavior.empty() {
    return HydrationBehavior(
      averageGlasses: 0,
      daysGoalMet: 0,
      totalDays: 1,
      goalAchievementRate: 0,
      peakHour: 12,
    );
  }

  Map<String, dynamic> toJson() => {
        'averageGlasses': averageGlasses,
        'daysGoalMet': daysGoalMet,
        'totalDays': totalDays,
        'goalAchievementRate': goalAchievementRate,
        'peakHour': peakHour,
        'hourlyDistribution': hourlyDistribution,
      };

  factory HydrationBehavior.fromJson(Map<String, dynamic> json) {
    return HydrationBehavior(
      averageGlasses: (json['averageGlasses'] ?? 0).toDouble(),
      daysGoalMet: json['daysGoalMet'] ?? 0,
      totalDays: json['totalDays'] ?? 1,
      goalAchievementRate: (json['goalAchievementRate'] ?? 0).toDouble(),
      peakHour: json['peakHour'] ?? 12,
      hourlyDistribution: List<int>.from(json['hourlyDistribution'] ?? []),
    );
  }
}

class RecoveryIndicators {
  final double averageSleepHours;
  final int? averageRestingHeartRate;
  final double weeklyTrainingLoad;
  final double weeklyVolume;
  final int consecutiveHighLoadDays;
  final bool isOvertraining;

  RecoveryIndicators({
    required this.averageSleepHours,
    this.averageRestingHeartRate,
    required this.weeklyTrainingLoad,
    required this.weeklyVolume,
    required this.consecutiveHighLoadDays,
    required this.isOvertraining,
  });

  factory RecoveryIndicators.empty() {
    return RecoveryIndicators(
      averageSleepHours: 0,
      averageRestingHeartRate: null,
      weeklyTrainingLoad: 0,
      weeklyVolume: 0,
      consecutiveHighLoadDays: 0,
      isOvertraining: false,
    );
  }

  Map<String, dynamic> toJson() => {
        'averageSleepHours': averageSleepHours,
        'averageRestingHeartRate': averageRestingHeartRate,
        'weeklyTrainingLoad': weeklyTrainingLoad,
        'weeklyVolume': weeklyVolume,
        'consecutiveHighLoadDays': consecutiveHighLoadDays,
        'isOvertraining': isOvertraining,
      };

  factory RecoveryIndicators.fromJson(Map<String, dynamic> json) {
    return RecoveryIndicators(
      averageSleepHours: (json['averageSleepHours'] ?? 0).toDouble(),
      averageRestingHeartRate: json['averageRestingHeartRate'],
      weeklyTrainingLoad: (json['weeklyTrainingLoad'] ?? 0).toDouble(),
      weeklyVolume: (json['weeklyVolume'] ?? 0).toDouble(),
      consecutiveHighLoadDays: json['consecutiveHighLoadDays'] ?? 0,
      isOvertraining: json['isOvertraining'] ?? false,
    );
  }
}
