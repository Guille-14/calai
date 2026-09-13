import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/utils/app_translations.dart';

class CircularProgressArc extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;
  final Widget? child;

  const CircularProgressArc({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 10,
    this.progressColor = AppColors.accentCalories,
    this.backgroundColor = const Color(0xFF2C2C2E),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _CircularProgressPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              progressColor: progressColor,
              backgroundColor: backgroundColor,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class DonutChart extends StatelessWidget {
  final double caloriesConsumed;
  final double caloriesGoal;
  final double size;

  const DonutChart({
    super.key,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    final progress = (caloriesConsumed / caloriesGoal).clamp(0.0, 1.5);
    final remaining = caloriesGoal - caloriesConsumed;

    return CircularProgressArc(
      progress: progress,
      size: size,
      strokeWidth: 14,
      progressColor: AppColors.accentCalories,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${caloriesConsumed.toInt()}',
            style: AppTextStyles.numberLarge.copyWith(
              fontSize: 36,
            ),
          ),
          Text(
            remaining >= 0
                ? '$remaining ${t.translate('remaining')}'
                : '${remaining.abs()} ${t.translate('over')}',
            style: AppTextStyles.caption.copyWith(
              color: remaining >= 0 ? AppColors.textTertiary : AppColors.coral,
            ),
          ),
        ],
      ),
    );
  }
}
