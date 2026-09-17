import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Skeleton ligero sin controlador global: no deja timers ni suscripciones
/// vivos cuando una pantalla desaparece.
class SkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.42, end: 0.72),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.elevatedCardBackground,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ScreenSkeleton extends StatelessWidget {
  final int cards;

  const ScreenSkeleton({super.key, this.cards = 4});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      children: [
        const SkeletonBlock(height: 28, width: 180, radius: 10),
        const SizedBox(height: 12),
        const SkeletonBlock(height: 16, width: 260, radius: 8),
        const SizedBox(height: 24),
        for (var i = 0; i < cards; i++) ...[
          const SkeletonBlock(height: 112, radius: 20),
          if (i != cards - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
