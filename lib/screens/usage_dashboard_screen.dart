import 'package:flutter/material.dart';

/// Aggregate stats shown to the user (total sessions, hours transcribed,
/// most-used mode, etc.). Computed from real session data once the Rust
/// bridge is wired — this screen defines the layout against a stats
/// summary type so wiring real numbers in later is a drop-in.
class UsageStats {
  final int totalSessions;
  final double totalMinutesTranscribed;
  final int totalSegments;
  final Map<String, int> sessionsByMode;

  const UsageStats({
    required this.totalSessions,
    required this.totalMinutesTranscribed,
    required this.totalSegments,
    required this.sessionsByMode,
  });

  factory UsageStats.empty() => const UsageStats(
        totalSessions: 0,
        totalMinutesTranscribed: 0,
        totalSegments: 0,
        sessionsByMode: {},
      );
}

class UsageDashboardScreen extends StatelessWidget {
  static const _emptyStats = UsageStats(
    totalSessions: 0,
    totalMinutesTranscribed: 0,
    totalSegments: 0,
    sessionsByMode: {},
  );

  final UsageStats stats;

  const UsageDashboardScreen({super.key, this.stats = _emptyStats});

  @override
  Widget build(BuildContext context) {
    final hours = (stats.totalMinutesTranscribed / 60).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik Penggunaan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(label: 'Total Sesi', value: '${stats.totalSessions}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(label: 'Jam Ditranskrip', value: hours),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(label: 'Total Segmen Transkrip', value: '${stats.totalSegments}'),
          const SizedBox(height: 24),
          if (stats.sessionsByMode.isEmpty)
            const Text('Belum ada data mode rapat.')
          else ...[
            Text('Sesi per Mode', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in stats.sessionsByMode.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text('${entry.value} sesi'),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
