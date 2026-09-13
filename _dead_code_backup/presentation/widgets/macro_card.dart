import 'package:flutter/material.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/utils/app_translations.dart';

class MacroCard extends StatelessWidget {
  final double caloriesConsumed;
  final double caloriesGoal;
  final double proteinConsumed;
  final double proteinGoal;
  final double carbsConsumed;
  final double carbsGoal;
  final double fatConsumed;
  final double fatGoal;

  const MacroCard({
    super.key,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.proteinConsumed,
    required this.proteinGoal,
    required this.carbsConsumed,
    required this.carbsGoal,
    required this.fatConsumed,
    required this.fatGoal,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.primary),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentCalories.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.tertiary),
                ),
                child: Text(
                  t.translate('daily_goals'),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accentCalories,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${caloriesConsumed.toInt()} / ${caloriesGoal.toInt()} ${t.translate('kcal')}',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildCaloriesDonut(t),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _MacroProgressBar(
                      label: t.translate('protein'),
                      current: proteinConsumed,
                      goal: proteinGoal,
                      color: AppColors.accentProtein,
                      unit: t.translate('g'),
                    ),
                    const SizedBox(height: 16),
                    _MacroProgressBar(
                      label: t.translate('carbs'),
                      current: carbsConsumed,
                      goal: carbsGoal,
                      color: AppColors.accentCarbs,
                      unit: t.translate('g'),
                    ),
                    const SizedBox(height: 16),
                    _MacroProgressBar(
                      label: t.translate('fat'),
                      current: fatConsumed,
                      goal: fatGoal,
                      color: AppColors.accentFat,
                      unit: t.translate('g'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesDonut(AppTranslations t) {
    final progress = (caloriesConsumed / caloriesGoal).clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return CustomPaint(
                painter: _DonutPainter(
                  progress: value,
                  progressColor: AppColors.accentCalories,
                  backgroundColor: const Color(0xFF2C2C2E),
                ),
              );
            },
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: caloriesConsumed),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Text(
                  '${value.toInt()}',
                  style: AppTextStyles.numberLarge.copyWith(fontSize: 28),
                );
              },
            ),
            Text(
              t.translate('kcal'),
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;

  _DonutPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -1.5708;
    final sweepAngle = 2 * 3.14159 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _MacroProgressBar extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;
  final String unit;

  const _MacroProgressBar({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (current / goal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${current.toInt()}/${goal.toInt()}$unit',
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Container(
              height: 8,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
