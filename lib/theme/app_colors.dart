import 'package:flutter/material.dart';

/// Color tokens per the design brief (light/dark), including the MIC/SPK
/// accent colors used throughout the transcript view and VU meters.
class AppColors {
  const AppColors._();

  static const Color micAccent = Color(0xFF34C759);
  static const Color spkAccent = Color(0xFFFF9F0A);
  static const Color warning = Color(0xFFFF3B30);
  static const Color recordingDot = Color(0xFFFF3B30);

  static const LightColors light = LightColors();
  static const DarkColors dark = DarkColors();
}

abstract class AppColorSet {
  const AppColorSet();
  Color get background;
  Color get surface;
  Color get primary;
  Color get text;
  Color get textSecondary;
  Color get divider;
}

class LightColors extends AppColorSet {
  const LightColors();
  @override
  Color get background => const Color(0xFFF5F5F7);
  @override
  Color get surface => const Color(0xFFFFFFFF);
  @override
  Color get primary => const Color(0xFF0A84FF);
  @override
  Color get text => const Color(0xFF1C1C1E);
  @override
  Color get textSecondary => const Color(0xFF626266);
  @override
  Color get divider => const Color(0xFFE5E5EA);
}

class DarkColors extends AppColorSet {
  const DarkColors();
  @override
  Color get background => const Color(0xFF1C1C1E);
  @override
  Color get surface => const Color(0xFF2C2C2E);
  @override
  Color get primary => const Color(0xFF0A84FF);
  @override
  Color get text => const Color(0xFFF5F5F7);
  @override
  Color get textSecondary => const Color(0xFFA1A1A6);
  @override
  Color get divider => const Color(0xFF3A3A3C);
}
