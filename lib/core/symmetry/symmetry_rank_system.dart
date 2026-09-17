import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum SymmetryRank {
  iron(0, 'Hierro', 0, 500, AppColors.textSecondary, Icons.circle_outlined),
  bronze(1, 'Bronce', 500, 2000, AppColors.accentMuted, Icons.shield_outlined),
  silver(2, 'Plata', 2000, 4000, AppColors.accentStrong, Icons.star_outline),
  gold(3, 'Oro', 4000, 5000, AppColors.accent, Icons.military_tech_outlined),
  platinum(4, 'Platino', 5000, 12000, AppColors.accentStrong, Icons.verified_outlined),
  emerald(5, 'Esmeralda', 12000, 30000, AppColors.accent, Icons.diamond_outlined),
  diamond(6, 'Diamante', 30000, 70000, AppColors.accentStrong, Icons.auto_awesome_outlined),
  master(7, 'Maestro', 70000, 150000, AppColors.accent, Icons.workspace_premium_outlined),
  champion(8, 'Campeón', 150000, 300000, AppColors.accentStrong, Icons.emoji_events_outlined),
  symmetric(9, 'Simétrico', 300000, double.infinity, AppColors.accent, Icons.all_inclusive);

  final int level;
  final String displayName;
  final double minXP;
  final double maxXP;
  final Color color;
  final IconData icon;

  const SymmetryRank(
    this.level,
    this.displayName,
    this.minXP,
    this.maxXP,
    this.color,
    this.icon,
  );

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
              'color': rank.color.toARGB32(),
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
