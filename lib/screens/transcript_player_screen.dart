import 'package:flutter/material.dart';

import '../state/models.dart';
import '../widgets/transcript_view.dart';

/// Playback UI for a saved session: seek slider synced to segment
/// timestamps + speed control. Actual audio decode/playback wiring lands
/// once FRB codegen is in place; this screen owns transport state so that
/// hookup is a drop-in later.
class TranscriptPlayerScreen extends StatefulWidget {
  final String title;
  final double durationSeconds;
  final List<TranscriptSegment> segments;

  const TranscriptPlayerScreen({
    super.key,
    required this.title,
    required this.durationSeconds,
    required this.segments,
  });

  @override
  State<TranscriptPlayerScreen> createState() => _TranscriptPlayerScreenState();
}

class _TranscriptPlayerScreenState extends State<TranscriptPlayerScreen> {
  double _positionSeconds = 0;
  double _speed = 1.0;
  bool _playing = false;

  static const _speedOptions = [0.5, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(child: TranscriptView(segments: widget.segments)),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(_formatTime(_positionSeconds)),
                Expanded(
                  child: Slider(
                    value: _positionSeconds.clamp(0, widget.durationSeconds),
                    max: widget.durationSeconds <= 0 ? 1 : widget.durationSeconds,
                    onChanged: (value) => setState(() => _positionSeconds = value),
                  ),
                ),
                Text(_formatTime(widget.durationSeconds)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 40,
                  icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  onPressed: () => setState(() => _playing = !_playing),
                ),
                const SizedBox(width: 16),
                DropdownButton<double>(
                  value: _speed,
                  items: _speedOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text('${s}x')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _speed = value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(double secs) {
    final m = (secs / 60).floor();
    final s = (secs % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
