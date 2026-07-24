import 'package:flutter/material.dart';

import '../state/models.dart';

class ModeSelector extends StatelessWidget {
  final SessionMode selected;
  final ValueChanged<SessionMode> onChanged;

  const ModeSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SessionMode>(
      segments: SessionMode.values
          .map((m) => ButtonSegment(value: m, label: Text(m.label)))
          .toList(),
      selected: {selected},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}
