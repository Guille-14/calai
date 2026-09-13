import 'package:flutter/material.dart';

class MuscleGroupRank {
  String
      muscleGroup; // chest, back, legs, shoulders, biceps, triceps, forearms, abs
  int currentRank; // 1-20
  double currentXP; // current XP within rank
  double nextRankXP; // XP needed for next rank
  double maxWeight; // Personal Max
  int maxReps;
  DateTime lastWorkedOut; // Last date this muscle was worked
  int totalWorkouts; // Total workouts for this muscle
  String color; // Color for visualization

  MuscleGroupRank({
    required this.muscleGroup,
    this.currentRank = 1,
    this.currentXP = 0,
    this.nextRankXP = 100,
    this.maxWeight = 0,
    this.maxReps = 0,
    required this.lastWorkedOut,
    this.totalWorkouts = 0,
    this.color = '',
  });

  factory MuscleGroupRank.fromJson(Map<String, dynamic> json) {
    return MuscleGroupRank(
      muscleGroup: json['muscleGroup'] as String,
      currentRank: json['currentRank'] as int? ?? 1,
      currentXP: (json['currentXP'] as num?)?.toDouble() ?? 0.0,
      nextRankXP: (json['nextRankXP'] as num?)?.toDouble() ?? 100.0,
      maxWeight: (json['maxWeight'] as num?)?.toDouble() ?? 0.0,
      maxReps: json['maxReps'] as int? ?? 0,
      lastWorkedOut: DateTime.parse(json['lastWorkedOut'] as String),
      totalWorkouts: json['totalWorkouts'] as int? ?? 0,
      color: json['color'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'muscleGroup': muscleGroup,
      'currentRank': currentRank,
      'currentXP': currentXP,
      'nextRankXP': nextRankXP,
      'maxWeight': maxWeight,
      'maxReps': maxReps,
      'lastWorkedOut': lastWorkedOut.toIso8601String(),
      'totalWorkouts': totalWorkouts,
      'color': color,
    };
  }

  double get progressPercentage => (currentXP / nextRankXP * 100).clamp(0, 100);

  StrengthRank get rankInfo => StrengthRankExtension.fromLevel(currentRank);
}

class BodyAnalysis {
  Map<String, MuscleGroupRank> muscleRanks; // key: muscleGroup
  DateTime analyzedAt;
  int overallLevel;
  List<String> weakPoints; // muscle groups needing work
  List<String> strongPoints; // best muscle groups

  BodyAnalysis({
    required this.muscleRanks,
    required this.analyzedAt,
    this.overallLevel = 1,
    this.weakPoints = const [],
    this.strongPoints = const [],
  });

  factory BodyAnalysis.fromJson(Map<String, dynamic> json) {
    final ranksData = json['muscleRanks'] as Map<String, dynamic>? ?? {};
    final muscleRanks = <String, MuscleGroupRank>{};
    ranksData.forEach((key, value) {
      muscleRanks[key] =
          MuscleGroupRank.fromJson(value as Map<String, dynamic>);
    });

    return BodyAnalysis(
      muscleRanks: muscleRanks,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
      overallLevel: json['overallLevel'] as int? ?? 1,
      weakPoints: List<String>.from(json['weakPoints'] as List? ?? []),
      strongPoints: List<String>.from(json['strongPoints'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    final ranksJson = <String, dynamic>{};
    muscleRanks.forEach((key, value) {
      ranksJson[key] = value.toJson();
    });

    return {
      'muscleRanks': ranksJson,
      'analyzedAt': analyzedAt.toIso8601String(),
      'overallLevel': overallLevel,
      'weakPoints': weakPoints,
      'strongPoints': strongPoints,
    };
  }
}

enum StrengthRank {
  hierro,
  bronce,
  plata,
  oro,
  platino,
  esmeralda,
  diamante,
  campeon,
  simetrico
}

extension StrengthRankExtension on StrengthRank {
  String get name {
    switch (this) {
      case StrengthRank.hierro:
        return 'Hierro';
      case StrengthRank.bronce:
        return 'Bronce';
      case StrengthRank.plata:
        return 'Plata';
      case StrengthRank.oro:
        return 'Oro';
      case StrengthRank.platino:
        return 'Platino';
      case StrengthRank.esmeralda:
        return 'Esmeralda';
      case StrengthRank.diamante:
        return 'Diamante';
      case StrengthRank.campeon:
        return 'Campeón';
      case StrengthRank.simetrico:
        return 'Simétrico';
    }
  }

  Color get color {
    switch (this) {
      case StrengthRank.hierro:
        return const Color(0xFF8E8E93);
      case StrengthRank.bronce:
        return const Color(0xFFCD7F32);
      case StrengthRank.plata:
        return const Color(0xFFC0C0C0);
      case StrengthRank.oro:
        return const Color(0xFFFFD700);
      case StrengthRank.platino:
        return const Color(0xFFE5E4E2);
      case StrengthRank.esmeralda:
        return const Color(0xFF50C878);
      case StrengthRank.diamante:
        return const Color(0xFFB9F2FF);
      case StrengthRank.campeon:
        return const Color(0xFFFF0000);
      case StrengthRank.simetrico:
        return const Color(0xFFE040FB);
    }
  }

  static StrengthRank fromLevel(int level) {
    if (level < 5) return StrengthRank.hierro;
    if (level < 15) return StrengthRank.bronce;
    if (level < 30) return StrengthRank.plata;
    if (level < 50) return StrengthRank.oro;
    if (level < 75) return StrengthRank.platino;
    if (level < 100) return StrengthRank.esmeralda;
    if (level < 130) return StrengthRank.diamante;
    if (level < 170) return StrengthRank.campeon;
    return StrengthRank.simetrico;
  }
}
