import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final AppColorSet colors = isDark ? AppColors.dark : AppColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.micAccent,
        onSecondary: Colors.white,
        error: AppColors.warning,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.text,
      ),
      dividerColor: colors.divider,
      textTheme: Typography.blackMountainView.apply(
        bodyColor: colors.text,
        displayColor: colors.text,
      ),
    );
  }
}
