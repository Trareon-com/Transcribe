import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';
import '../utils/format_time.dart';

/// Card widget for displaying a session summary in the library list.
class SessionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final double durationSeconds;
  final int segmentsCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const SessionCard({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.date,
    this.durationSeconds = 0,
    this.segmentsCount = 0,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final durStr = formatDurationLabel(durationSeconds);

    return Card(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.mic_outlined,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          durStr,
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 12,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$segmentsCount segmen',
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              IconButton(
                icon: Icon(
                  Icons.upload_outlined,
                  size: 18,
                  color: colors.textTertiary,
                ),
                tooltip: 'Export',
                onPressed: onExport,
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: colors.textTertiary,
                ),
                tooltip: 'Hapus',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Creates a [SessionCard] from a [SessionSummary] model.
class SessionCardFromSummary extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  const SessionCardFromSummary({
    super.key,
    required this.session,
    required this.onTap,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SessionCard(
      title: session.title,
      subtitle: session.date,
      date: session.date,
      durationSeconds: session.durationSeconds,
      segmentsCount: session.segmentsCount,
      onTap: onTap,
      onDelete: onDelete,
      onExport: onExport,
    );
  }
}
