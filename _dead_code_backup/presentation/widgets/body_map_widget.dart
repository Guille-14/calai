import 'package:flutter/material.dart';
import '../../models/strength_ranks_model.dart';

class BodyMapPainter extends CustomPainter {
  final BodyAnalysis bodyAnalysis;

  BodyMapPainter(this.bodyAnalysis);

  Color _getRankColor(int rank) {
    // Color gradient based on rank
    if (rank <= 3) return const Color(0xFF666666); // Gray - Beginner
    if (rank <= 6) return const Color(0xFF44B0FF); // Blue - Intermediate
    if (rank <= 10) return const Color(0xFF00D084); // Green - Advanced
    if (rank <= 14) return const Color(0xFFFFD700); // Gold - Elite
    return const Color(0xFFFF4444); // Red - Legend
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final centerX = width / 2;

    // Draw simplified body silhouette with muscle group zones
    _drawHead(canvas, centerX, height * 0.08, width);
    _drawChest(canvas, centerX, height * 0.2, width, height);
    _drawBack(canvas, centerX, height * 0.2, width, height);
    _drawShoulders(canvas, centerX, height * 0.18, width, height);
    _drawArms(canvas, centerX, height * 0.25, width, height);
    _drawForearms(canvas, centerX, height * 0.35, width, height);
    _drawAbs(canvas, centerX, height * 0.32, width, height);
    _drawLegs(canvas, centerX, height * 0.45, width, height);
  }

  void _drawHead(Canvas canvas, double centerX, double top, double width) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX, top), width * 0.08, paint);
  }

  void _drawChest(
      Canvas canvas, double centerX, double top, double width, double height) {
    final rank = bodyAnalysis.muscleRanks['chest'];
    final paint = Paint()
      ..color = _getRankColor(rank?.currentRank ?? 1)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(centerX - width * 0.15, top);
    path.lineTo(centerX + width * 0.15, top);
    path.lineTo(centerX + width * 0.12, top + height * 0.12);
    path.lineTo(centerX - width * 0.12, top + height * 0.12);
    path.close();

    canvas.drawPath(path, paint);

    // Draw dividing line
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(centerX, top),
      Offset(centerX, top + height * 0.12),
      linePaint,
    );
  }

  void _drawBack(
      Canvas canvas, double centerX, double top, double width, double height) {
    // Back is drawn but mostly invisible unless rotated
    final rank = bodyAnalysis.muscleRanks['back'];
    final paint = Paint()
      ..color = _getRankColor(rank?.currentRank ?? 1).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Back silhouette
    final path = Path();
    path.moveTo(centerX - width * 0.16, top + height * 0.02);
    path.lineTo(centerX + width * 0.16, top + height * 0.02);
    path.lineTo(centerX + width * 0.14, top + height * 0.15);
    path.lineTo(centerX - width * 0.14, top + height * 0.15);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawShoulders(
      Canvas canvas, double centerX, double top, double width, double height) {
    final rank = bodyAnalysis.muscleRanks['shoulders'];
    final paint = Paint()
      ..color = _getRankColor(rank?.currentRank ?? 1)
      ..style = PaintingStyle.fill;

    // Left shoulder
    canvas.drawCircle(
      Offset(centerX - width * 0.18, top),
      width * 0.06,
      paint,
    );

    // Right shoulder
    canvas.drawCircle(
      Offset(centerX + width * 0.18, top),
      width * 0.06,
      paint,
    );
  }

  void _drawArms(
      Canvas canvas, double centerX, double top, double width, double height) {
    final bicepsRank = bodyAnalysis.muscleRanks['biceps'];
    final tricepsRank = bodyAnalysis.muscleRanks['triceps'];

    final bicepsPaint = Paint()
      ..color = _getRankColor(bicepsRank?.currentRank ?? 1)
      ..style = PaintingStyle.fill;

    final tricepsPaint = Paint()
      ..color = _getRankColor(tricepsRank?.currentRank ?? 1)
      ..style = PaintingStyle.fill;

    // Left arm (biceps - front)
    final leftBicepsPath = Path();
    leftBicepsPath.moveTo(centerX - width * 0.18, top - height * 0.05);
    leftBicepsPath.lineTo(centerX - width * 0.16, top);
    leftBicepsPath.lineTo(centerX - width * 0.2, top + height * 0.08);
    leftBicepsPath.close();
    canvas.drawPath(leftBicepsPath, bicepsPaint);

    // Right arm (biceps - front)
    final rightBicepsPath = Path();
    rightBicepsPath.moveTo(centerX + width * 0.18, top - height * 0.05);
    rightBicepsPath.lineTo(centerX + width * 0.16, top);
    rightBicepsPath.lineTo(centerX + width * 0.2, top + height * 0.08);
    rightBicepsPath.close();
    canvas.drawPath(rightBicepsPath, bicepsPaint);
  }

  void _drawForearms(
      Canvas canvas, double centerX, double top, double width, double height) {
    final rank = bodyAnalysis.muscleRanks['forearms'];
    final paint = Paint()
      ..color = _getRankColor(rank?.currentRank ?? 1)
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    // Left forearm
    canvas.drawLine(
      Offset(centerX - width * 0.2, top - height * 0.03),
      Offset(centerX - width * 0.21, top + height * 0.07),
      paint,
    );

    // Right forearm
    canvas.drawLine(
      Offset(centerX + width * 0.2, top - height * 0.03),
      Offset(centerX + width * 0.21, top + height * 0.07),
      paint,
    );
  }

  void _drawAbs(
      Canvas canvas, double centerX, double top, double width, double height) {
    final rank = bodyAnalysis.muscleRanks['abs'];
    final paint = Paint()
      ..color = _getRankColor(rank?.currentRank ?? 1)
      ..style = PaintingStyle.fill;

    // Abdominal area
    final path = Path();
    path.moveTo(centerX - width * 0.09, top);
    path.lineTo(centerX + width * 0.09, top);
    path.lineTo(centerX + width * 0.08, top + height * 0.18);
    path.lineTo(centerX - width * 0.08, top + height * 0.18);
    path.close();

    canvas.drawPath(path, paint);

    // Draw 6-pack divisions
    final dividerPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;

    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(centerX - width * 0.09, top + (height * 0.18 / 3) * i),
        Offset(centerX + width * 0.09, top + (height * 0.18 / 3) * i),
        dividerPaint,
      );
    }
  }

  void _drawLegs(
      Canvas canvas, double centerX, double top, double width, double height) {
    final rank = bodyAnalysis.muscleRanks['legs'];
    final paint = Paint()
      ..color = _getRankColor(rank?.currentRank ?? 1)
      ..style = PaintingStyle.fill;

    // Left leg
    final leftLegPath = Path();
    leftLegPath.moveTo(centerX - width * 0.08, top);
    leftLegPath.lineTo(centerX - width * 0.06, top);
    leftLegPath.lineTo(centerX - width * 0.07, top + height * 0.25);
    leftLegPath.lineTo(centerX - width * 0.09, top + height * 0.25);
    leftLegPath.close();
    canvas.drawPath(leftLegPath, paint);

    // Right leg
    final rightLegPath = Path();
    rightLegPath.moveTo(centerX + width * 0.08, top);
    rightLegPath.lineTo(centerX + width * 0.06, top);
    rightLegPath.lineTo(centerX + width * 0.07, top + height * 0.25);
    rightLegPath.lineTo(centerX + width * 0.09, top + height * 0.25);
    rightLegPath.close();
    canvas.drawPath(rightLegPath, paint);
  }

  @override
  bool shouldRepaint(BodyMapPainter oldDelegate) {
    return oldDelegate.bodyAnalysis != bodyAnalysis;
  }
}

class BodyMapWidget extends StatelessWidget {
  final BodyAnalysis bodyAnalysis;

  const BodyMapWidget({super.key, required this.bodyAnalysis});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 200,
          height: 350,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: CustomPaint(
            painter: BodyMapPainter(bodyAnalysis),
            size: const Size(200, 350),
          ),
        ),
        const SizedBox(height: 16),
        // Legend of body parts
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: bodyAnalysis.muscleRanks.entries.map((entry) {
              final rank = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildMuscleLegendItem(entry.key, rank),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMuscleLegendItem(String muscleName, MuscleGroupRank rank) {
    final rankColor = _getRankColorForRank(rank.currentRank);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: rankColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rankColor,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${rank.currentRank}',
            style: TextStyle(
              color: rankColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            muscleName,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColorForRank(int rank) {
    if (rank <= 3) return const Color(0xFF666666);
    if (rank <= 6) return const Color(0xFF4ECDC4);
    if (rank <= 10) return const Color(0xFF00C853);
    if (rank <= 14) return const Color(0xFFFFD700);
    return const Color(0xFFFF6B6B);
  }
}
