import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/preference_manager.dart';
import '../../data/models/user_data.dart';

class CalorieRing extends StatelessWidget {
  final double consumed;
  final double goal;

  const CalorieRing({
    super.key,
    required this.consumed,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (goal - consumed).clamp(0.0, goal);
    final progress = (consumed / goal).clamp(0.0, 1.0);
    final primaryColor = AppColors.primary;

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(240, 240),
            painter: _CalorieRingPainter(
              progress: progress,
              progressColor: primaryColor,
              backgroundColor: AppColors.cardBackground,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                remaining.toInt().toString(),
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.0,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'restantes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;

  _CalorieRingPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 44) / 2;
    const strokeWidth = 22.0;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          progressColor,
          progressColor.withValues(alpha: 0.7),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class MacroPill extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;

  const MacroPill({
    super.key,
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (current / goal).clamp(0.0, 1.0);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${current.toInt()}g',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(5),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DailyTrackerPremium extends StatefulWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const DailyTrackerPremium({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  State<DailyTrackerPremium> createState() => _DailyTrackerPremiumState();
}

class _DailyTrackerPremiumState extends State<DailyTrackerPremium> {
  UserData? userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final prefManager = PreferenceManager(prefs);
    userData = prefManager.getUserData();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final targetCalories = userData?.estimatedCalories.toDouble() ?? 2000.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [AppTheme.softShadow],
      ),
      child: Column(
        children: [
          CalorieRing(
            consumed: widget.calories,
            goal: targetCalories,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              const SizedBox(width: 8),
              MacroPill(
                label: 'Proteína',
                current: widget.protein,
                goal: (userData?.proteinGoal ?? 50).toDouble(),
                color: AppColors.proteinColor,
              ),
              const SizedBox(width: 16),
              MacroPill(
                label: 'Grasas',
                current: widget.fat,
                goal: (userData?.fatGoal ?? 65).toDouble(),
                color: AppColors.fatColor,
              ),
              const SizedBox(width: 16),
              MacroPill(
                label: 'Carbs',
                current: widget.carbs,
                goal: (userData?.carbsGoal ?? 250).toDouble(),
                color: AppColors.carbsColor,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}
