import 'package:flutter/material.dart';

import '../state/session_model.dart';
import '../theme/app_colors.dart';

class ResourceHud extends StatelessWidget {
  final SessionLifecycle lifecycle;
  final int segmentsCount;

  const ResourceHud({super.key, required this.lifecycle, required this.segmentsCount});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final isRecording = lifecycle == SessionLifecycle.recording;
    final isPaused = lifecycle == SessionLifecycle.paused;
    final statusColor = isRecording
        ? AppColors.statusActive
        : isPaused
            ? Colors.orange
            : colors.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: isRecording
                  ? [BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _statusLabel(lifecycle),
            style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            '$segmentsCount segmen',
            style: TextStyle(color: colors.textTertiary, fontSize: 11),
          ),
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
