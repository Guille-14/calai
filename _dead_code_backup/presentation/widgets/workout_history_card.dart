import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/workout_models.dart';
import '../../core/utils/app_translations.dart';

/// Widget para mostrar una tarjeta de historial de entrenamiento
/// Reutilizable en pantallas de historial, pantalla principal, etc.
class WorkoutHistoryCard extends StatelessWidget {
  final WorkoutSession session;
  final VoidCallback? onTap;
  final bool isCompact;

  const WorkoutHistoryCard({
    super.key,
    required this.session,
    this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    final dateFormatter = DateFormat('EEEE, MMM d');
    final sessionName = session.routineName ?? 'Empty Workout';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF2F2F7), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sessionName,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormatter.format(session.date),
                            style: const TextStyle(fontSize: 13, color: Colors.black38, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black26),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStat(Icons.timer_outlined, '${session.durationMinutes}m'),
                    const SizedBox(width: 16),
                    _buildStat(Icons.fitness_center_rounded, '${session.exercises.length} Exercises'),
                    const SizedBox(width: 16),
                    _buildStat(Icons.line_weight_rounded, '${session.totalVolume} kg'),
                  ],
                ),
                const SizedBox(height: 16),
                // Exercise highlights
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: session.exercises.take(3).map((ex) {
                    final bestSet = ex.sets.reduce((a, b) => (a.weight * a.reps) > (b.weight * b.reps) ? a : b);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${ex.name} (${bestSet.weight}kg x ${bestSet.reps})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54),
                      ),
                    );
                  }).toList(),
                ),
                if (session.exercises.length > 3)
                   Padding(
                     padding: const EdgeInsets.only(top: 8),
                     child: Text(
                       'and ${session.exercises.length - 3} more...',
                       style: const TextStyle(fontSize: 11, color: Colors.black26, fontStyle: FontStyle.italic),
                     ),
                   ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF3B82F6)),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
      ],
    );
  }
}

