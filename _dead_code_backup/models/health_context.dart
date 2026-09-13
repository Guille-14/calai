
class HealthContext {
  final int stepsToday;
  final double activeCaloriesToday;
  final DateTime lastSyncTimestamp;

  HealthContext({
    required this.stepsToday,
    required this.activeCaloriesToday,
    required this.lastSyncTimestamp,
  });

  factory HealthContext.fromJson(Map<String, dynamic> json) {
    return HealthContext(
      stepsToday: json['stepsToday'] as int,
      activeCaloriesToday: (json['activeCaloriesToday'] as num).toDouble(),
      lastSyncTimestamp: DateTime.parse(json['lastSyncTimestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stepsToday': stepsToday,
      'activeCaloriesToday': activeCaloriesToday,
      'lastSyncTimestamp': lastSyncTimestamp.toIso8601String(),
    };
  }

  HealthContext copyWith({
    int? stepsToday,
    double? activeCaloriesToday,
    DateTime? lastSyncTimestamp,
  }) {
    return HealthContext(
      stepsToday: stepsToday ?? this.stepsToday,
      activeCaloriesToday: activeCaloriesToday ?? this.activeCaloriesToday,
      lastSyncTimestamp: lastSyncTimestamp ?? this.lastSyncTimestamp,
    );
  }

  @override
  String toString() {
    return 'HealthContext{stepsToday: $stepsToday, activeCaloriesToday: $activeCaloriesToday, lastSyncTimestamp: $lastSyncTimestamp}';
  }
}
