import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/app_translations.dart';
import '../cubit/food_log_cubit.dart';
import 'popups.dart';

class WaterTracker extends StatelessWidget {
  const WaterTracker({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);

    return BlocBuilder<FoodLogCubit, FoodLogState>(
      buildWhen: (previous, current) =>
          previous.waterGlasses != current.waterGlasses ||
          previous.waterGoal != current.waterGoal,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade400,
                Colors.blue.shade600,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.water_drop,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        t.translate('water'),
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
                      horizontal: 12,
                      vertical: 6,
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
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _WaterButton(
                    icon: Icons.remove,
                    onTap: state.waterGlasses > 0
                        ? () => context.read<FoodLogCubit>().removeWaterGlass()
                        : null,
                  ),
                  const SizedBox(width: 20),
                  _WaterDisplay(state: state),
                  const SizedBox(width: 20),
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
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (state.waterGlasses / state.waterGoal).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '${(state.waterGlasses * 250)}ml / ${(state.waterGoal * 250)}ml',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
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
        width: 48,
        height: 48,
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

class _WaterDisplay extends StatelessWidget {
  final FoodLogState state;

  const _WaterDisplay({required this.state});

  @override
  Widget build(BuildContext context) {
    final completed = state.waterGlasses >= state.waterGoal;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: (state.waterGlasses / state.waterGoal).clamp(0.0, 1.0),
                strokeWidth: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  completed ? Colors.green.shade300 : Colors.white,
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  '${state.waterGlasses}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(
                  Icons.water_drop,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
        if (completed) ...[
          const SizedBox(height: 8),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
              SizedBox(width: 4),
              Text(
                '¡Meta alcanzada!',
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
    );
  }
}
