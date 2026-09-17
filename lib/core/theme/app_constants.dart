import 'package:flutter/material.dart';

import 'app_theme.dart';

// Reexportamos los tokens para que las pantallas antiguas que importan
// app_constants.dart sigan usando exactamente la misma paleta.
export 'app_theme.dart' show AppColors;

class AppRadius {
  static const double primary = 24.0;
  static const double secondary = 16.0;
  static const double tertiary = 12.0;
  static const double button = 50.0;
}

/// Las tarjetas de CalAI son planas. Se conservan estos getters por
/// compatibilidad con widgets antiguos, pero no generan sombras.
class AppShadows {
  static List<BoxShadow> get card => const [];
  static List<BoxShadow> get soft => const [];
  static List<BoxShadow> get elevated => const [];
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  static const TextStyle numberLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle numberMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
}
