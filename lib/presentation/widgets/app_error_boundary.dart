import 'package:flutter/material.dart';

import 'app_error_fallback.dart';

/// Boundary global para fallos GRAVES y no recuperables.
///
/// IMPORTANTE: activar este boundary sustituye la aplicación entera por la
/// pantalla de error, así que [report] solo debe llamarse cuando la app
/// realmente no puede continuar.
///
/// Antes lo invocaba `FlutterError.onError`, es decir, cualquier aviso del
/// framework (un overflow de layout, una imagen que no carga, un setState
/// tardío). Como esos errores son habituales y casi siempre inofensivos, la
/// app se sustituía por la pantalla de error constantemente. Ahora esos casos
/// los aísla Flutter en el widget afectado vía `ErrorWidget.builder`.
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
