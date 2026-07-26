import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StreamToggle extends StatelessWidget {
  final String label;
  final bool enabled;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const StreamToggle({
    super.key,
    required this.label,
    required this.enabled,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Indonesian semantic label per toggle type
    String semanticLabel;
    if (label == 'Mic') {
      semanticLabel = enabled ? 'Mikrofon aktif' : 'Mikrofon nonaktif';
    } else if (label == 'Speaker') {
      semanticLabel = enabled ? 'Pengeras suara aktif' : 'Pengeras suara nonaktif';
    } else {
      semanticLabel = '$label ${enabled ? 'aktif' : 'nonaktif'}';
    }

    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Semantics(
      label: semanticLabel,
      child: GestureDetector(
        onTap: () => onChanged(!enabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.15)
                : colors.chipBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: enabled ? accent.withValues(alpha: 0.4) : colors.border,
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? accent : colors.textTertiary,
                  boxShadow: enabled
                      ? [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? accent : colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                enabled ? 'ON' : 'OFF',
                style: TextStyle(
                  color: enabled ? accent : colors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
