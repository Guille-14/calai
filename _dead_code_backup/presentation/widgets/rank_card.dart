import 'package:flutter/material.dart';
import '../../models/strength_ranks_model.dart';

class RankCard extends StatelessWidget {
  final String muscleGroup;
  final MuscleGroupRank rank;
  final VoidCallback? onTap;

  const RankCard({
    super.key,
    required this.muscleGroup,
    required this.rank,
    this.onTap,
  });

  Color _getRankColor() {
    if (rank.currentRank <= 3) return const Color(0xFF666666);
    if (rank.currentRank <= 6) return const Color(0xFF4ECDC4);
    if (rank.currentRank <= 10) return const Color(0xFF00C853);
    if (rank.currentRank <= 14) return const Color(0xFFFFD700);
    return const Color(0xFFFF6B6B);
  }

  String _getRankTitle() {
    if (rank.currentRank <= 3) return 'BEGINNER';
    if (rank.currentRank <= 6) return 'INTERMEDIATE';
    if (rank.currentRank <= 10) return 'ADVANCED';
    if (rank.currentRank <= 14) return 'ELITE';
    return 'LEGEND';
  }

  IconData _getMuscleIcon() {
    switch (muscleGroup) {
      case 'chest':
        return Icons.favorite;
      case 'back':
        return Icons.assessment;
      case 'legs':
        return Icons.directions_run;
      case 'shoulders':
        return Icons.shield;
      case 'biceps':
        return Icons.fitness_center;
      case 'triceps':
        return Icons.fitness_center;
      case 'forearms':
        return Icons.pan_tool;
      case 'abs':
        return Icons.remove;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = _getRankColor();
    final rankTitle = _getRankTitle();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              rankColor.withOpacity(0.15),
              rankColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: rankColor.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: rankColor.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and rank
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: rankColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getMuscleIcon(),
                        color: rankColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          muscleGroup.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          rankTitle,
                          style: TextStyle(
                            color: rankColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [rankColor, rankColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: rankColor.withOpacity(0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${rank.currentRank}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Stats row
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'MAX',
                    '${rank.maxWeight.toStringAsFixed(0)} kg',
                    rankColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'REPS',
                    '${rank.maxReps}x',
                    rankColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'WORKOUTS',
                    '${rank.totalWorkouts}',
                    rankColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RANK PROGRESS',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${rank.progressPercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: rank.progressPercentage / 100,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Last workout: ${_formatLastWorkout(rank.lastWorkedOut)}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatLastWorkout(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).ceil()}w ago';
    } else {
      return '${(diff.inDays / 30).ceil()}m ago';
    }
  }
}
