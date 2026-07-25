import 'package:flutter/material.dart';

import '../state/session_model.dart';
import '../theme/app_colors.dart';

class ResourceHud extends StatelessWidget {
  final SessionLifecycle lifecycle;
  final int segmentsCount;

  const ResourceHud({super.key, required this.lifecycle, required this.segmentsCount});

  @override
  Widget build(BuildContext context) {
    final isRecording = lifecycle == SessionLifecycle.recording;
    final isPaused = lifecycle == SessionLifecycle.paused;
    final statusColor = isRecording
        ? AppColors.recordingDot
        : isPaused
            ? Colors.orange
            : Theme.of(context).disabledColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: isRecording
                      ? [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(_statusLabel(lifecycle), style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
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
