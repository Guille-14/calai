import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Fallback visual de producción para errores de renderizado.
/// No expone stack traces ni detalles internos al usuario final.
class AppErrorFallback extends StatelessWidget {
  const AppErrorFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.error,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Algo no salió como esperábamos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vuelve a intentarlo. Tus datos guardados están protegidos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
