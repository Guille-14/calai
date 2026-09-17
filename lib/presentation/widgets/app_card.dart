import 'package:flutter/material.dart';

import '../../core/theme/app_constants.dart';

/// Superficie base del sistema de diseño: sin sombras duras, borde sutil y
/// feedback táctil consistente.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.semanticLabel,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: color ?? AppColors.cardBackground,
      borderRadius: BorderRadius.circular(AppRadius.secondary),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.secondary),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.secondary),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.07),
            ),
          ),
          child: child,
        ),
      ),
    );

    return semanticLabel == null
        ? card
        : Semantics(label: semanticLabel, button: onTap != null, child: card);
  }
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
