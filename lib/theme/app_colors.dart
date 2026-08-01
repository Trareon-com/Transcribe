import 'package:flutter/material.dart';

/// Color tokens for Trareon Transcribe — teal-green primary palette
/// matching the redesign mockup. Light/dark variants included.
class AppColors {
  const AppColors._();

  // Primary palette — teal-green accent
  static const Color primary = Color(0xFF00796B);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primaryDark = Color(0xFF004D40);

  // Speaker accent colors
  static const Color micAccent = Color(0xFF00796B);
  static const Color spkAccent = Color(0xFF00796B);

  // Status colors
  static const Color statusActive = Color(0xFF2E7D32);
  static const Color statusError = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFF3B30);
  static const Color recordingDot = Color(0xFFFF3B30);

  // Light theme
  static const LightColors light = LightColors();
  // Dark theme
  static const DarkColors dark = DarkColors();
}

abstract class AppColorSet extends ThemeExtension<AppColorSet> {
  const AppColorSet();

  @override
  AppColorSet copyWith() => this;

  @override
  AppColorSet lerp(ThemeExtension<AppColorSet>? other, double t) {
    if (other is! AppColorSet) return this;
    return t < 0.5 ? this : other;
  }

  Color get background;
  Color get surface;
  Color get surfaceElevated;
  Color get primary;
  Color get onPrimary;
  Color get text;
  Color get textSecondary;
  Color get textTertiary;
  Color get divider;
  Color get border;
  Color get chipBackground;
  Color get chipSelectedBackground;
  Color get headerBackground;
  Color get transcriptBackground;
  Color get primaryDark;
}

class LightColors extends AppColorSet {
  const LightColors();
  @override
  Color get background => const Color(0xFFF5F5F5);
  @override
  Color get surface => const Color(0xFFFFFFFF);
  @override
  Color get surfaceElevated => const Color(0xFFFFFFFF);
  @override
  Color get primary => const Color(0xFF00796B);
  @override
  Color get primaryDark => const Color(0xFF004D40);
  @override
  Color get onPrimary => const Color(0xFFFFFFFF);
  @override
  Color get text => const Color(0xFF333333);
  @override
  Color get textSecondary => const Color(0xFF666666);
  @override
  Color get textTertiary => const Color(0xFF757575);
  @override
  Color get divider => const Color(0xFFE0E0E0);
  @override
  Color get border => const Color(0xFFE0E0E0);
  @override
  Color get chipBackground => const Color(0xFFF0F0F0);
  @override
  Color get chipSelectedBackground => const Color(0xFF00796B);
  @override
  Color get headerBackground => const Color(0xFFFFFFFF);
  @override
  Color get transcriptBackground => const Color(0xFFFFFFFF);
}

class DarkColors extends AppColorSet {
  const DarkColors();
  @override
  Color get background => const Color(0xFF121212);
  @override
  Color get surface => const Color(0xFF1E1E1E);
  @override
  Color get surfaceElevated => const Color(0xFF2C2C2C);
  @override
  Color get primary => const Color(0xFF4DB6AC);
  @override
  Color get primaryDark => const Color(0xFF00796B);
  @override
  Color get onPrimary => const Color(0xFF003D33);
  @override
  Color get text => const Color(0xFFE0E0E0);
  @override
  Color get textSecondary => const Color(0xFFB0B0B0);
  @override
  Color get textTertiary => const Color(0xFF9E9E9E);
  @override
  Color get divider => const Color(0xFF333333);
  @override
  Color get border => const Color(0xFF333333);
  @override
  Color get chipBackground => const Color(0xFF2C2C2C);
  @override
  Color get chipSelectedBackground => const Color(0xFF4DB6AC);
  @override
  Color get headerBackground => const Color(0xFF1E1E1E);
  @override
  Color get transcriptBackground => const Color(0xFF1E1E1E);
}
