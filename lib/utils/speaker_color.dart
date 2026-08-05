import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const _palette = [
  Color(0xFF00796B),
  Color(0xFFE67E22),
  Color(0xFF2ECC71),
  Color(0xFF9B59B6),
  Color(0xFFE74C3C),
  Color(0xFF1ABC9C),
  Color(0xFF3498DB),
  Color(0xFFF39C12),
];

Color speakerColor(String name, AppColorSet colors) {
  if (name.isEmpty) return colors.primary;
  return _palette[name.hashCode.abs() % _palette.length];
}
