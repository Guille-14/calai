import 'package:flutter/material.dart';
import '../../core/theme/app_constants.dart';
import '../../core/utils/app_translations.dart';

class DailyActivitySummaryCard extends StatelessWidget {
  final int? steps;
  final double? caloriesBurned;
  final double? kilometers;
  final bool isHealthConnectActive;

  const DailyActivitySummaryCard({
    super.key,
    this.steps,
    this.caloriesBurned,
    this.kilometers,
    this.isHealthConnectActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    if (!isHealthConnectActive) {
      return _buildEmptyState(context, t);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentCalories.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_run,
                  color: AppColors.accentCalories,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                t.translate('daily_activity'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ActivityMetric(
                  icon: Icons.directions_walk,
                  label: t.translate('steps'),
                  value: steps != null ? steps!.toString() : '0',
                  unit: '',
                  color: AppColors.royalBlue,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: AppColors.divider,
              ),
              Expanded(
                child: _ActivityMetric(
                  icon: Icons.local_fire_department,
                  label: t.translate('calories'),
                  value: caloriesBurned != null
                      ? '${caloriesBurned!.toInt()}'
                      : '0',
                  unit: t.translate('kcal'),
                  color: AppColors.coral,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: AppColors.divider,
              ),
              Expanded(
                child: _ActivityMetric(
                  icon: Icons.straighten,
                  label: t.translate('distance'),
                  value: kilometers != null
                      ? kilometers!.toStringAsFixed(2)
                      : '0.00',
                  unit: t.translate('km_short'),
                  color: AppColors.emerald,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppTranslations t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.watch_off,
              color: AppColors.textTertiary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.translate('no_activity_data'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.translate('connect_health_track'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _ActivityMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          unit.isNotEmpty ? '$label ($unit)' : label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
