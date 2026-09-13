import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/ai/readiness_engine.dart';

class ReadinessScoreWidget extends StatelessWidget {
  final ReadinessScore? score;
  final VoidCallback? onRefresh;

  const ReadinessScoreWidget({
    super.key,
    this.score,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return _buildLoadingState();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getGradientColors(score!.score),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getGradientColors(score!.score)[0].withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Preparación',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onRefresh != null)
                GestureDetector(
                  onTap: onRefresh,
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score!.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '/100',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                  ),
                ),
              ),
              const Spacer(),
              _buildScoreIndicator(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            score!.recommendation,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          if (score!.factors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: score!.factors
                  .take(3)
                  .map((f) => _buildFactorChip(f))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          _buildScoreBreakdown(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
          SizedBox(width: 16),
          Text(
            'Calculando preparación...',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreIndicator() {
    IconData icon;
    if (score!.score >= 80) {
      icon = Icons.trending_up;
    } else if (score!.score >= 60) {
      icon = Icons.check_circle;
    } else if (score!.score >= 40) {
      icon = Icons.warning_amber;
    } else {
      icon = Icons.pause_circle;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  Widget _buildFactorChip(String factor) {
    final isPositive = factor.startsWith('✓');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        factor,
        style: TextStyle(
          color: isPositive ? Colors.green.shade200 : Colors.orange.shade200,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildScoreBreakdown() {
    return Column(
      children: [
        const Divider(color: Colors.white24, height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMiniScore('🚶', score!.stepsScore),
            _buildMiniScore('🔥', score!.caloriesScore),
            _buildMiniScore('💧', score!.hydrationScore),
            _buildMiniScore('😴', score!.sleepScore),
            _buildMiniScore('📊', score!.consistencyScore),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniScore(String emoji, int value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          '$value%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  List<Color> _getGradientColors(int score) {
    if (score >= 80) {
      return [const Color(0xFF34C759), const Color(0xFF30D158)];
    } else if (score >= 60) {
      return [const Color(0xFF5E5CE6), const Color(0xFF7D7AFF)];
    } else if (score >= 40) {
      return [const Color(0xFFFF9500), const Color(0xFFFFAA33)];
    } else {
      return [const Color(0xFFFF3B30), const Color(0xFFFF6961)];
    }
  }
}

class ReadinessRingWidget extends StatelessWidget {
  final int score;
  final double size;

  const ReadinessRingWidget({
    super.key,
    required this.score,
    this.size = 120,
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
            painter: _RingPainter(
              progress: score / 100,
              color: _getColor(score),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getLabel(score),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: size * 0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColor(int score) {
    if (score >= 80) return const Color(0xFF34C759);
    if (score >= 60) return const Color(0xFF5E5CE6);
    if (score >= 40) return const Color(0xFFFF9500);
    return const Color(0xFFFF3B30);
  }

  String _getLabel(int score) {
    if (score >= 80) return 'Excelente';
    if (score >= 60) return 'Bueno';
    if (score >= 40) return 'Moderado';
    return 'Bajo';
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
