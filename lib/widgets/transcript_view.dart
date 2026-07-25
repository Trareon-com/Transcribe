import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';

/// Virtualized transcript list — `ListView.builder` + `itemExtent` so long
/// sessions (thousands of segments) stay smooth (see architecture
/// bottleneck notes: avoid full-list rebuilds for live sessions).
///
/// Pass [onEdit] to enable inline editing (tap a segment to correct its
/// text) — used by the transcript player for saved sessions; the live
/// main-screen view omits it since editing mid-recording doesn't apply.
class TranscriptView extends StatelessWidget {
  final List<TranscriptSegment> segments;
  final void Function(int index, String newText)? onEdit;

  const TranscriptView({super.key, required this.segments, this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const Center(child: Text('Belum ada transkrip. Mulai sesi untuk memulai.'));
    }

    return ListView.builder(
      itemCount: segments.length,
      itemExtent: 64,
      itemBuilder: (context, index) => _SegmentTile(
        segment: segments[index],
        onEdit: onEdit == null ? null : (newText) => onEdit!(index, newText),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final TranscriptSegment segment;
  final ValueChanged<String>? onEdit;

  const _SegmentTile({required this.segment, this.onEdit});

  Future<void> _openEditDialog(BuildContext context) async {
    final controller = TextEditingController(text: segment.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Transkrip'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    // Not disposed here: the dialog's closing transition can still touch
    // the controller for a frame after showDialog resolves. It's a
    // short-lived local controller, so leaving it to be garbage collected
    // (rather than racing dispose() against the animation) is the safer
    // trade-off. See https://github.com/flutter/flutter/issues/106549
    if (newText != null && newText.trim().isNotEmpty && newText != segment.text) {
      onEdit?.call(newText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = segment.source == 'mic' ? AppColors.micAccent : AppColors.spkAccent;
    final editable = onEdit != null;
    return InkWell(
      onTap: editable ? () => _openEditDialog(context) : null,
      child: Padding(
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
            if (editable)
              Icon(Icons.edit_outlined, size: 16, color: Theme.of(context).disabledColor),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(double secs) {
    final m = (secs / 60).floor();
    final s = (secs % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
