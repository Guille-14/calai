import 'package:flutter/material.dart';

enum SymmetryRank {
  iron(0, 'Hierro', 0, 500, Colors.grey),
  bronze(1, 'Bronce', 500, 2000, const Color(0xFFCD7F32)),
  silver(2, 'Plata', 2000, 5000, Colors.blueGrey),
  gold(3, 'Oro', 5000, 12000, Colors.amber),
  platinum(4, 'Platino', 12000, 30000, const Color(0xFFE5E4E2)),
  emerald(5, 'Esmeralda', 30000, 70000, Colors.green),
  diamond(6, 'Diamante', 70000, 150000, const Color(0xFFB9F2FF)),
  master(7, 'Maestro', 150000, 300000, const Color(0xFF9B59B6)),
  champion(8, 'Campeón', 300000, 600000, const Color(0xFFE74C3C)),
  symmetric(9, 'Simétrico', 600000, double.infinity, const Color(0xFFFFD700));

  final int level;
  final String displayName;
  final double minXP;
  final double maxXP;
  final Color color;

  const SymmetryRank(
      this.level, this.displayName, this.minXP, this.maxXP, this.color);

  static SymmetryRank fromXP(double xp) {
    for (final rank in SymmetryRank.values) {
      if (xp < rank.maxXP) return rank;
    }
    return SymmetryRank.symmetric;
  }

  static SymmetryRank fromLevel(int level) {
    if (level < 0 || level >= SymmetryRank.values.length) {
      return SymmetryRank.iron;
    }
    return SymmetryRank.values[level];
  }

  SymmetryRank? get nextRank {
    if (this == SymmetryRank.symmetric) return null;
    return SymmetryRank.values[level + 1];
  }

  static List<Map<String, dynamic>> getRankHierarchy() {
    return SymmetryRank.values
        .map((rank) => {
              'name': rank.displayName,
              'level': rank.level,
              'minXP': rank.minXP,
              'color': rank.color.value,
            })
        .toList();
  }
}

class SymmetryProgress {
  final double totalXP;
  final SymmetryRank currentRank;
  final double rankProgress;
  final double dailyXP;
  final double weeklyXP;
  final double streakDays;
  final double proteinMultiplier;
  final bool metProteinGoal;

  const SymmetryProgress({
    required this.totalXP,
    required this.currentRank,
    required this.rankProgress,
    required this.dailyXP,
    required this.weeklyXP,
    required this.streakDays,
    required this.proteinMultiplier,
    required this.metProteinGoal,
  });

  factory SymmetryProgress.empty() {
    return const SymmetryProgress(
      totalXP: 0,
      currentRank: SymmetryRank.iron,
      rankProgress: 0,
      dailyXP: 0,
      weeklyXP: 0,
      streakDays: 0,
      proteinMultiplier: 1.0,
      metProteinGoal: false,
    );
  }

  double get effectiveXP => totalXP * proteinMultiplier;

  Map<String, dynamic> toJson() => {
        'totalXP': totalXP,
        'currentRank': currentRank.level,
        'rankProgress': rankProgress,
        'dailyXP': dailyXP,
        'weeklyXP': weeklyXP,
        'streakDays': streakDays,
        'proteinMultiplier': proteinMultiplier,
        'metProteinGoal': metProteinGoal,
      };

  factory SymmetryProgress.fromJson(Map<String, dynamic> json) {
    return SymmetryProgress(
      totalXP: (json['totalXP'] as num?)?.toDouble() ?? 0,
      currentRank:
          SymmetryRank.fromLevel((json['currentRank'] as num?)?.toInt() ?? 0),
      rankProgress: (json['rankProgress'] as num?)?.toDouble() ?? 0,
      dailyXP: (json['dailyXP'] as num?)?.toDouble() ?? 0,
      weeklyXP: (json['weeklyXP'] as num?)?.toDouble() ?? 0,
      streakDays: (json['streakDays'] as num?)?.toDouble() ?? 0,
      proteinMultiplier: (json['proteinMultiplier'] as num?)?.toDouble() ?? 1.0,
      metProteinGoal: json['metProteinGoal'] as bool? ?? false,
    );
  }
}
