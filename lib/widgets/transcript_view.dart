import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';

class TranscriptView extends StatefulWidget {
  final List<TranscriptSegment> segments;
  final void Function(int index, String newText)? onEdit;

  const TranscriptView({super.key, required this.segments, this.onEdit});

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    const threshold = 50.0;
    final atBottom = pos.maxScrollExtent - pos.pixels < threshold;
    if (_autoScroll != atBottom) {
      setState(() => _autoScroll = atBottom);
    }
  }

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
    _searchController.dispose();
    super.dispose();
  }

  void _copyAllToClipboard(BuildContext context) {
    if (widget.segments.isEmpty) return;
    final text = widget.segments
        .map((s) => '[${s.speaker} · ${_formatTime(s.timestamp)}] ${s.text}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transkrip disalin ke clipboard'), duration: Duration(seconds: 2)),
    );
  }

  String _formatTime(double secs) {
    final m = (secs / 60).floor();
    final s = (secs % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    if (widget.segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_none_outlined, size: 48, color: colors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Belum ada transkrip',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Mulai sesi untuk memulai transkripsi',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search + Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: colors.text, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Cari...',
                      hintStyle: TextStyle(color: colors.textTertiary, fontSize: 12),
                      prefixIcon: Icon(Icons.search, size: 14, color: colors.textTertiary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 14, color: colors.textTertiary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.chipBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.segments.length} segmen',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              IconButton(
                tooltip: _autoScroll ? 'Auto-scroll aktif' : 'Auto-scroll mati',
                icon: Icon(
                  _autoScroll ? Icons.vertical_align_bottom : Icons.pause_circle_outline,
                  size: 18,
                  color: _autoScroll ? colors.primary : colors.textTertiary,
                ),
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
              ),
              IconButton(
                tooltip: 'Salin semua',
                icon: Icon(Icons.copy_outlined, size: 18, color: colors.textSecondary),
                onPressed: () => _copyAllToClipboard(context),
              ),
            ],
          ),
        ),

        // Transcript list
        Expanded(
          child: Builder(
            builder: (context) {
              final query = _searchQuery.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? widget.segments
                  : widget.segments
                      .where((s) => s.text.toLowerCase().contains(query) || s.speaker.toLowerCase().contains(query))
                      .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    query.isNotEmpty ? 'Tidak ada segmen cocok' : 'Belum ada transkrip',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: filtered.length,
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

  String _formatTime(double secs) {
    final m = (secs / 60).floor();
    final s = (secs % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final isMic = segment.source == 'mic';

    return Semantics(
      label: '${segment.speaker} pada ${_formatTime(segment.timestamp)}: ${segment.text}',
      child: InkWell(
        onTap: onEdit != null ? () => _openEditDialog(context) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Speaker label
              Container(
                width: 40,
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  segment.speaker,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      segment.text,
                      style: TextStyle(color: colors.text, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatTime(segment.timestamp),
                          style: TextStyle(color: colors.textTertiary, fontSize: 11),
                        ),
                        if (segment.language.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.chipBackground,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              segment.language.toUpperCase(),
                              style: TextStyle(color: colors.textTertiary, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                Icon(Icons.edit_outlined, size: 14, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditDialog(BuildContext context) {
    final controller = TextEditingController(text: segment.text);
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Edit Transkrip', style: TextStyle(color: colors.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          style: TextStyle(color: colors.text),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: colors.chipBackground,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ).then((newText) {
      if (newText != null && newText.trim().isNotEmpty && newText != segment.text) {
        onEdit?.call(newText);
      }
    });
  }
}
