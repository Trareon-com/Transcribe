import 'package:flutter/material.dart';

import '../state/models.dart';

class ModeSelector extends StatelessWidget {
  final SessionMode selected;
  final ValueChanged<SessionMode> onChanged;

  const ModeSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pilih mode sesi. Mode saat ini: ${selected.label}',
      child: SegmentedButton<SessionMode>(
        segments: SessionMode.values
            .map((m) => ButtonSegment(
                  value: m,
                  label: Semantics(
                    label: m == SessionMode.webinar
                        ? 'Mode webinar: hanya pengeras suara'
                        : m == SessionMode.online
                            ? 'Mode rapat online: mikrofon dan pengeras suara'
                            : 'Mode rapat offline: hanya mikrofon',
                    child: Text(m.label),
                  ),
                ))
            .toList(),
        selected: {selected},
        onSelectionChanged: (set) => onChanged(set.first),
      ),
    );
  }
}
