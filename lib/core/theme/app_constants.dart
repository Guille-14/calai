import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF000000);
  static const Color cardBackground = Color(0xFF111111);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x61FFFFFF);

  static const Color accentProtein = Color(0xFF00C853);
  static const Color accentCarbs = Color(0xFF2196F3);
  static const Color accentFat = Color(0xFFFFAB00);
  static const Color accentCalories = Color(0xFF00C853);

  static const Color healthBlue = Color(0xFF1A73E8);
  static const Color goalPurple = Color(0xFF7C4DFF);
  
  static const Color coral = Color(0xFFFF6B6B);
  static const Color emerald = Color(0xFF00C853);
  static const Color royalBlue = Color(0xFF2196F3);

  static const Color divider = Color(0xFF222222);
  static const Color cardShadow = Color(0x40000000);
}


class AppRadius {
  static const double primary = 24.0;
  static const double secondary = 16.0;
  static const double tertiary = 12.0;
  static const double button = 50.0;
}

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.cardShadow,
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: AppColors.cardShadow,
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 30,
          offset: const Offset(0, 8),
        ),
      ];
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
