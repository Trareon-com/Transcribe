import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';

/// Virtualized transcript list — `ListView.builder` + `itemExtent` so long
/// sessions (thousands of segments) stay smooth (see architecture
/// bottleneck notes: avoid full-list rebuilds for live sessions).
///
/// Includes action toolbar with live keyword search, 1-click clipboard copy,
/// and auto-scroll pin control.
class TranscriptView extends StatefulWidget {
  final List<TranscriptSegment> segments;
  final void Function(int index, String newText)? onEdit;

  const TranscriptView({super.key, required this.segments, this.onEdit});

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _autoScroll = true;

  @override
  void didUpdateWidget(TranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.segments.length > oldWidget.segments.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _copyAllToClipboard(BuildContext context) {
    if (widget.segments.isEmpty) return;
    final text = widget.segments
        .map((s) => '[${s.speaker} · ${_formatSecs(s.timestamp)}] ${s.text}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transkrip berhasil disalin ke clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatSecs(double secs) {
    final m = (secs / 60).floor();
    final s = (secs % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.segments.isEmpty) {
      return const Center(child: Text('Belum ada transkrip. Mulai sesi untuk memulai.'));
    }

    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.segments
        : widget.segments
            .where((s) =>
                s.text.toLowerCase().contains(query) ||
                s.speaker.toLowerCase().contains(query))
            .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Cari dalam transkrip...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text('${filtered.length} cocok'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              IconButton(
                tooltip: _autoScroll ? 'Auto-scroll aktif' : 'Auto-scroll mati',
                icon: Icon(
                  _autoScroll ? Icons.vertical_align_bottom : Icons.pause_circle_outline,
                  color: _autoScroll ? Theme.of(context).colorScheme.primary : null,
                ),
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
              ),
              IconButton(
                tooltip: 'Salin Seluruh Transkrip',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () => _copyAllToClipboard(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Tidak ada segmen yang cocok.'))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: filtered.length,
                  itemExtent: 64,
                  itemBuilder: (context, index) {
                    final seg = filtered[index];
                    final originalIndex = widget.segments.indexOf(seg);
                    return _SegmentTile(
                      segment: seg,
                      onEdit: widget.onEdit == null
                          ? null
                          : (newText) => widget.onEdit!(originalIndex, newText),
                    );
                  },
                ),
        ),
      ],
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
