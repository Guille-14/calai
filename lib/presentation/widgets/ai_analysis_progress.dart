import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum AiAnalysisStage {
  preparing,
  analyzing,
  validating,
  completed,
}

class AiAnalysisProgress extends StatelessWidget {
  final AiAnalysisStage stage;
  final String provider;
  final String model;

  const AiAnalysisProgress({
    super.key,
    required this.stage,
    required this.provider,
    required this.model,
  });

  static const _stages = <AiAnalysisStage>[
    AiAnalysisStage.preparing,
    AiAnalysisStage.analyzing,
    AiAnalysisStage.validating,
  ];

  String get _message => switch (stage) {
        AiAnalysisStage.preparing => 'Identificando alimentos en el plato...',
        AiAnalysisStage.analyzing => 'Calculando volumen y porciones...',
        AiAnalysisStage.validating => 'Extrayendo macronutrientes...',
        AiAnalysisStage.completed => 'Análisis listo',
      };

  @override
  Widget build(BuildContext context) {
    final index = _stages.indexOf(stage).clamp(0, _stages.length - 1);
    return Semantics(
      liveRegion: true,
      label: _message,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                _message,
                key: ValueKey(stage),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$provider · $model',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                for (var i = 0; i < _stages.length; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= index
                            ? AppColors.accent
                            : AppColors.divider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (i != _stages.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
