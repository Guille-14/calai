class TrainingSuggestion {
  final String exerciseName;
  final double suggestedWeight;
  final String weightRationale;
  final int suggestedReps;
  final String repRationale;
  final int suggestedRestSeconds;
  final String restRationale;
  final bool isPR;
  final double estimated1RM;
  final double fatigueAdjustment;
  final String volumeBalance;
  final String muscleImbalance;
  final double weeklyLoadStatus;
  final double sleepQuality;
  final double consistencyLevel;

  TrainingSuggestion({
    required this.exerciseName,
    required this.suggestedWeight,
    required this.weightRationale,
    required this.suggestedReps,
    required this.repRationale,
    required this.suggestedRestSeconds,
    required this.restRationale,
    required this.isPR,
    required this.estimated1RM,
    required this.fatigueAdjustment,
    required this.volumeBalance,
    required this.muscleImbalance,
    required this.weeklyLoadStatus,
    required this.sleepQuality,
    required this.consistencyLevel,
  });
}
