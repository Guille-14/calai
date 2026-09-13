import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Widget RPG que muestra el buff de recuperación de CalAI
class NutritionBoostWidget extends StatefulWidget {
  final bool isActive;
  final double multiplier;
  final double proteinPercent;
  final String proteinStatus;

  const NutritionBoostWidget({
    Key? key,
    required this.isActive,
    required this.multiplier,
    required this.proteinPercent,
    required this.proteinStatus,
  }) : super(key: key);

  @override
  State<NutritionBoostWidget> createState() => _NutritionBoostWidgetState();
}

class _NutritionBoostWidgetState extends State<NutritionBoostWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(NutritionBoostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isActive ? _pulseAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isActive
                    ? [
                        AppColors.neonGreen.withOpacity(0.2),
                        AppColors.accentGold.withOpacity(0.1),
                      ]
                    : [
                        AppColors.rpgCardDark,
                        AppColors.rpgCardDark.withOpacity(0.8),
                      ],
              ),
              border: Border.all(
                color: widget.isActive
                    ? AppColors.neonGreen
                    : AppColors.textTertiary.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: AppColors.neonGreen.withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Icono del buff
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isActive
                        ? AppColors.neonGreen.withOpacity(0.2)
                        : AppColors.rpgDark.withOpacity(0.5),
                    border: Border.all(
                      color: widget.isActive
                          ? AppColors.neonGreen
                          : AppColors.textTertiary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    widget.isActive ? Icons.flash_on : Icons.flash_off,
                    color: widget.isActive
                        ? AppColors.neonGreen
                        : AppColors.textTertiary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Información del buff
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'RECUPERACIÓN',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: widget.isActive
                                  ? AppColors.neonGreen
                                  : AppColors.textTertiary,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isActive
                                  ? AppColors.neonGreen.withOpacity(0.2)
                                  : AppColors.rpgDark,
                              border: Border.all(
                                color: widget.isActive
                                    ? AppColors.neonGreen
                                    : AppColors.textTertiary.withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'x${widget.multiplier.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: widget.isActive
                                    ? AppColors.neonGreen
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.proteinStatus,
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isActive
                              ? AppColors.neonGreen
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress circular
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: widget.proteinPercent.clamp(0, 1),
                        backgroundColor: AppColors.rpgDark,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isActive
                              ? AppColors.neonGreen
                              : AppColors.proteinColor,
                        ),
                        strokeWidth: 3,
                      ),
                      Text(
                        '${(widget.proteinPercent * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.isActive
                              ? AppColors.neonGreen
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
