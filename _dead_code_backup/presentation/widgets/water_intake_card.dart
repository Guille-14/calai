import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/app_translations.dart';
import '../cubit/food_log_cubit.dart';
import 'popups.dart';

class WaterIntakeCard extends StatelessWidget {
  const WaterIntakeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    return BlocBuilder<FoodLogCubit, FoodLogState>(
      buildWhen: (previous, current) =>
          previous.waterGlasses != current.waterGlasses ||
          previous.waterGoal != current.waterGoal,
      builder: (context, state) {
        final progress = (state.waterGlasses / state.waterGoal).clamp(0.0, 1.0);
        final liters = (state.waterGlasses * 0.25);
        final goalLiters = (state.waterGoal * 0.25);
        final isComplete = state.waterGlasses >= state.waterGoal;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade400,
                Colors.blue.shade600,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.water_drop,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        t.translate('water_intake'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${state.waterGlasses}/${state.waterGoal}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _WaterButton(
                    icon: Icons.remove,
                    onTap: state.waterGlasses > 0
                        ? () => context.read<FoodLogCubit>().removeWaterGlass()
                        : null,
                  ),
                  const SizedBox(width: 24),
                  Column(
                    children: [
                      Text(
                        '${liters.toStringAsFixed(2)}L',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.translate('of')} ${goalLiters.toStringAsFixed(2)}L',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                      if (isComplete) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.greenAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              t.translate('goal_reached'),
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 24),
                  _WaterButton(
                    icon: Icons.add,
                    onTap: () {
                      context.read<FoodLogCubit>().addWaterGlass();
                      final newCount = state.waterGlasses + 1;
                      final isGoalReached = newCount >= state.waterGoal;
                      WaterAddedPopup.show(
                        context,
                        glassCount: newCount,
                        goal: state.waterGoal,
                        isGoalReached: isGoalReached,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WaterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _WaterButton({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: onTap != null ? 0.3 : 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
