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

    return Semantics(
      label: semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? accent : AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(label),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}
