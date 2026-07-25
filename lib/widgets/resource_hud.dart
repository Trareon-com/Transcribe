import 'package:flutter/material.dart';

import '../state/session_model.dart';

class ResourceHud extends StatelessWidget {
  final SessionLifecycle lifecycle;
  final int segmentsCount;

  const ResourceHud({super.key, required this.lifecycle, required this.segmentsCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_statusLabel(lifecycle), style: Theme.of(context).textTheme.labelSmall),
          Text('$segmentsCount segmen', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  String _statusLabel(SessionLifecycle lifecycle) => switch (lifecycle) {
        SessionLifecycle.idle => 'Siap',
        SessionLifecycle.recording => 'Merekam…',
        SessionLifecycle.paused => 'Dijeda',
        SessionLifecycle.stopped => 'Berhenti',
      };
}
