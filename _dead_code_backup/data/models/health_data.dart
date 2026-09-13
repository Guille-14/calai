class HealthData {
  final int steps;
  final int stepsGoal;
  final int activeCalories;
  final int activeCaloriesGoal;
  final double distanceKm;
  final double distanceGoalKm;
  final String? deviceName;
  final DateTime lastSync;

  HealthData({
    required this.steps,
    required this.stepsGoal,
    required this.activeCalories,
    required this.activeCaloriesGoal,
    this.distanceKm = 0.0,
    this.distanceGoalKm = 8.0,
    this.deviceName,
    required this.lastSync,
  });

  double get stepsProgress => (steps / stepsGoal).clamp(0.0, 1.0);
  double get caloriesProgress =>
      (activeCalories / activeCaloriesGoal).clamp(0.0, 1.0);
  double get distanceProgress => (distanceKm / distanceGoalKm).clamp(0.0, 1.0);

  factory HealthData.empty() {
    return HealthData(
      steps: 0,
      stepsGoal: 10000,
      activeCalories: 0,
      activeCaloriesGoal: 500,
      distanceKm: 0.0,
      distanceGoalKm: 8.0,
      deviceName: null,
      lastSync: DateTime.now(),
    );
  }

  factory HealthData.simulated() {
    return HealthData(
      steps: 7842,
      stepsGoal: 10000,
      activeCalories: 342,
      activeCaloriesGoal: 500,
      distanceKm: 5.8,
      distanceGoalKm: 8.0,
      deviceName: 'Simulated Data',
      lastSync: DateTime.now().subtract(const Duration(minutes: 5)),
    );
  }
}
