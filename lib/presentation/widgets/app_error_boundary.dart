import 'package:flutter/material.dart';

import 'app_error_fallback.dart';

/// Boundary global para errores de renderizado recuperables.
///
/// Flutter continúa enviando el detalle técnico a los logs de desarrollo,
/// pero el usuario recibe una pantalla estable y una acción de recuperación.
class AppErrorBoundary extends StatefulWidget {
  final Widget child;

  const AppErrorBoundary({super.key, required this.child});

  static final ValueNotifier<bool> _hasError = ValueNotifier<bool>(false);

  static void report(Object error, StackTrace stack) {
    debugPrint('AppErrorBoundary: $error\n$stack');
    _hasError.value = true;
  }

  static void reset() => _hasError.value = false;

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  @override
  void initState() {
    super.initState();
    AppErrorBoundary._hasError.addListener(_onErrorChanged);
  }

  @override
  void dispose() {
    AppErrorBoundary._hasError.removeListener(_onErrorChanged);
    super.dispose();
  }

  void _onErrorChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (AppErrorBoundary._hasError.value) {
      return AppErrorFallback(onRetry: AppErrorBoundary.reset);
    }
    return widget.child;
  }
}
