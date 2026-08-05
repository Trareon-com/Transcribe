import 'package:flutter/material.dart';

import '../state/session_model.dart';
import '../theme/app_colors.dart';

/// Resource HUD: recording status, elapsed time, CPU, RAM, segment count
class ResourceHud extends StatelessWidget {
  final SessionLifecycle lifecycle;
  final int segmentsCount;
  final double elapsedSeconds;
  final double cpuUsage;
  final double ramUsageGb;
  final String modelName;

  const ResourceHud({
    super.key,
    required this.lifecycle,
    required this.segmentsCount,
    this.elapsedSeconds = 0,
    this.cpuUsage = 0,
    this.ramUsageGb = 0,
    this.modelName = '',
  });

  String _formatElapsed(double secs) {
    final h = (secs / 3600).floor();
    final m = ((secs % 3600) / 60).floor();
    final s = (secs % 60).floor();
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

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
          // Recording dot + elapsed
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
            isRecording ? _formatElapsed(elapsedSeconds) : _statusLabel(lifecycle),
            style: TextStyle(
              color: isRecording ? colors.text : colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),

          if (isRecording && modelName.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: colors.chipBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                modelName,
                style: TextStyle(color: colors.textTertiary, fontSize: 10),
              ),
            ),
          ],

          const Spacer(),

          // CPU
          if (cpuUsage > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '🖥️ ${cpuUsage.toStringAsFixed(0)}%',
                style: TextStyle(color: colors.textTertiary, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),

          // RAM
          if (ramUsageGb > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '🧠 ${ramUsageGb.toStringAsFixed(1)} GB',
                style: TextStyle(color: colors.textTertiary, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),

          // Segments
          Text(
            '🗣️ $segmentsCount',
            style: TextStyle(color: colors.textTertiary, fontSize: 11, fontFamily: 'monospace'),
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
