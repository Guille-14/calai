import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_skeleton.dart';

/// Estado de carga reutilizable para pantallas que consultan datos locales o
/// remotos. Evita que cada pantalla invente su propio spinner o error.
class AsyncStateView extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final Widget child;
  final int skeletonCards;

  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.error,
    required this.child,
    this.onRetry,
    this.skeletonCards = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ScreenSkeleton(cards: skeletonCards);
    }
    if (error != null) {
      return _LoadError(message: error!, onRetry: onRetry);
    }
    return child;
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _LoadError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: AppColors.error, size: 44),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
