import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/symmetry/symmetry_rank_system.dart';

/// Widget RPG que muestra el rango actual del usuario con animaciones
class RankBadgeWidget extends StatefulWidget {
  final SymmetryProgress progress;
  final VoidCallback? onTap;

  const RankBadgeWidget({
    Key? key,
    required this.progress,
    this.onTap,
  }) : super(key: key);

  @override
  State<RankBadgeWidget> createState() => _RankBadgeWidgetState();
}

class _RankBadgeWidgetState extends State<RankBadgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Color _getRankColor() {
    return widget.progress.currentRank.color;
  }

  IconData _getRankIcon() {
    final rank = widget.progress.currentRank;
    switch (rank) {
      case SymmetryRank.iron:
        return Icons.shield;
      case SymmetryRank.bronze:
        return Icons.shield;
      case SymmetryRank.silver:
        return Icons.shield_moon;
      case SymmetryRank.gold:
        return Icons.star;
      case SymmetryRank.platinum:
        return Icons.diamond;
      case SymmetryRank.emerald:
        return Icons.diamond;
      case SymmetryRank.diamond:
        return Icons.diamond;
      case SymmetryRank.master:
        return Icons.whatshot;
      case SymmetryRank.champion:
        return Icons.flare;
      case SymmetryRank.symmetric:
        return Icons.grade;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = _getRankColor();
    final nextRank = widget.progress.currentRank.nextRank;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.rpgCardDark,
              AppColors.rpgCardDark.withOpacity(0.5),
            ],
          ),
          border: Border.all(
            color: rankColor.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: rankColor.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Medalla animada del rango
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: rankColor.withOpacity(0.6 * _glowAnimation.value),
                        blurRadius: 30 * _glowAnimation.value,
                        spreadRadius: 10 * _glowAnimation.value,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Fondo circular
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              rankColor.withOpacity(0.4),
                              rankColor.withOpacity(0.1),
                            ],
                          ),
                          border: Border.all(
                            color: rankColor,
                            width: 2,
                          ),
                        ),
                      ),
                      // Icono del rango
                      Icon(
                        _getRankIcon(),
                        size: 50,
                        color: rankColor,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Nombre del rango
            Text(
              widget.progress.currentRank.displayName.toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: rankColor,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),

            // XP actual
            Text(
              '${widget.progress.totalXP.toStringAsFixed(0)} XP',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),

            // Barra de XP animada
            _buildXPBar(nextRank, rankColor),
            const SizedBox(height: 8),

            // Texto de progreso
            _buildProgressText(nextRank),
          ],
        ),
      ),
    );
  }

  Widget _buildXPBar(SymmetryRank? nextRank, Color rankColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: widget.progress.rankProgress.clamp(0, 1),
            backgroundColor: AppColors.rpgDark,
            valueColor: AlwaysStoppedAnimation<Color>(rankColor),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(widget.progress.rankProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.neonCyan,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (nextRank != null)
              Text(
                'Próximo: ${nextRank.displayName}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressText(SymmetryRank? nextRank) {
    if (nextRank == null) {
      return const Text(
        '¡Has alcanzado el rango máximo!',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.neonGold,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final xpNeeded =
        nextRank.minXP - widget.progress.totalXP;
    return Text(
      'Faltan ${xpNeeded.toStringAsFixed(0)} XP',
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.neonCyan,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

// Extensión de colores para acceder fácilmente
extension AppColorsRPG on AppColors {
  static const Color neonGold = AppColors.accentGold;
}
