import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme/app_colors.dart';
import '../widgets/transcript_view.dart';

class TranscriptPlayerScreen extends StatefulWidget {
  final String title;
  final double durationSeconds;
  final List<TranscriptSegment> segments;
  final ValueChanged<List<TranscriptSegment>>? onSegmentsChanged;

  const TranscriptPlayerScreen({
    super.key,
    required this.title,
    required this.durationSeconds,
    required this.segments,
    this.onSegmentsChanged,
  });

  @override
  State<TranscriptPlayerScreen> createState() => _TranscriptPlayerScreenState();
}

class _TranscriptPlayerScreenState extends State<TranscriptPlayerScreen> {
  double _positionSeconds = 0;
  double _speed = 1.0;
  bool _playing = false;
  late List<TranscriptSegment> _segments;

  static const _speedOptions = [0.5, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _segments = List.of(widget.segments);
  }

  void _editSegment(int index, String newText) {
    setState(() {
      _segments[index] = _segments[index].copyWith(text: newText);
    });
    widget.onSegmentsChanged?.call(List.unmodifiable(_segments));
  }

  String _formatTime(double secs) {
    final m = (secs / 60).floor();
    final s = (secs % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        foregroundColor: colors.text,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Transcript
          Expanded(
            child: TranscriptView(
              segments: _segments,
              onEdit: _editSegment,
            ),
          ),

          // Player controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: Column(
              children: [
                // Seek slider
                Row(
                  children: [
                    Text(_formatTime(_positionSeconds),
                      style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _positionSeconds.clamp(0, widget.durationSeconds),
                        max: widget.durationSeconds <= 0 ? 1 : widget.durationSeconds,
                        activeColor: colors.primary,
                        onChanged: (v) => setState(() => _positionSeconds = v),
                      ),
                    ),
                    Text(_formatTime(widget.durationSeconds),
                      style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  ],
                ),

                // Play controls + speed
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 40,
                      icon: Icon(
                        _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: colors.primary,
                      ),
                      onPressed: () => setState(() => _playing = !_playing),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: colors.chipBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.border),
                      ),
                      child: DropdownButton<double>(
                        value: _speed,
                        isDense: true,
                        underline: const SizedBox(),
                        dropdownColor: colors.surface,
                        style: TextStyle(color: colors.text, fontSize: 13),
                        items: _speedOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text('${s}x')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _speed = v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
