import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';

/// Virtualized transcript list — `ListView.builder` + `itemExtent` so long
/// sessions (thousands of segments) stay smooth (see architecture
/// bottleneck notes: avoid full-list rebuilds for live sessions).
class TranscriptView extends StatelessWidget {
  final List<TranscriptSegment> segments;

  const TranscriptView({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const Center(child: Text('Belum ada transkrip. Mulai sesi untuk memulai.'));
    }

    return ListView.builder(
      itemCount: segments.length,
      itemExtent: 64,
      itemBuilder: (context, index) => _SegmentTile(segment: segments[index]),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final TranscriptSegment segment;

  const _SegmentTile({required this.segment});

  @override
  Widget build(BuildContext context) {
    final accent = segment.source == 'mic' ? AppColors.micAccent : AppColors.spkAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 40, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${segment.speaker} · ${_formatTimestamp(segment.timestamp)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(segment.text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(double secs) {
    final m = (secs / 60).floor();
    final s = (secs % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
