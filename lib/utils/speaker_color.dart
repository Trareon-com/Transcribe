import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared palette-based speaker color assignment.
///
/// Extracted from `transcript_view.dart` so every surface that renders a
/// speaker label (transcript, player, summary) resolves the same color.
const _palette = [
  Color(0xFF00796B), // teal (primary)
  Color(0xFFE67E22), // orange
  Color(0xFF2ECC71), // green
  Color(0xFF9B59B6), // purple
  Color(0xFFE74C3C), // red
  Color(0xFF1ABC9C), // teal light
  Color(0xFF3498DB), // blue
  Color(0xFFF39C12), // amber
];

Color speakerColor(String name, AppColorSet colors) {
  if (name.isEmpty) return colors.primary;
  return _palette[name.hashCode.abs() % _palette.length];
}
