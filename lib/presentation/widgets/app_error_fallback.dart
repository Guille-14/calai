import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Fallback visual de producción para errores de renderizado.
/// No expone stack traces ni detalles internos al usuario final.
class AppErrorFallback extends StatelessWidget {
  final VoidCallback? onRetry;

  const AppErrorFallback({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Este widget es el sustituto de un widget que YA ha fallado, y también se
    // usa como pantalla de arranque de emergencia. En esos casos puede quedar
    // fuera del MaterialApp, sin `Directionality` encima: `Text` lanzaría
    // entonces su propio error y provocaría un bucle de fallos. Se aporta el
    // contexto mínimo aquí para que el fallback nunca pueda fallar.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
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
              if (onRetry != null) ...[
                const SizedBox(height: 22),
                FilledButton.icon(
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
