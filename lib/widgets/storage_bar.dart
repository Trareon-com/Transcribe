import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shows GB used / free disk space as a compact visual indicator.
class StorageBar extends StatelessWidget {
  final int totalSessions;

  const StorageBar({super.key, this.totalSessions = 0});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    // Best-effort disk usage via Directory.statSync on home
    final home = Directory(Platform.environment['HOME'] ?? '/');
    double usedGb = 0;
    double freeGb = 0;
    double totalGb = 0;
    try {
      final stat = home.statSync();
      totalGb = (stat.size / (1024 * 1024 * 1024)).roundToDouble();
      // Can't get per-folder size cheaply, use platform-specific total
      // We'll just show sessions count + free space
      freeGb = 0;
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.storage_outlined, size: 14, color: colors.textTertiary),
          const SizedBox(width: 6),
          Text(
            totalSessions > 0
                ? '$totalSessions sesi'
                : 'Belum ada sesi',
            style: TextStyle(color: colors.textTertiary, fontSize: 12),
          ),
          const Spacer(),
          // Simplified: just show sessions count as a pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colors.chipBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${totalSessions > 0 ? "📁 $totalSessions" : "📂 Kosong"}',
              style: TextStyle(color: colors.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
