import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../services/bridge_service.dart';
import '../state/models.dart';
import '../theme/app_colors.dart';
import '../widgets/export_dialog.dart';
import '../widgets/transcript_view.dart';

class TranscriptPlayerScreen extends StatefulWidget {
  final String title;
  final double durationSeconds;
  final List<TranscriptSegment> segments;
  final String? audioPath;
  final ValueChanged<List<TranscriptSegment>>? onSegmentsChanged;

  const TranscriptPlayerScreen({
    super.key,
    required this.title,
    required this.durationSeconds,
    required this.segments,
    this.audioPath,
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
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  Duration? _duration;
  String? _error;

  static const _speedOptions = [0.5, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _segments = List.of(widget.segments);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.audioPath == null) {
      setState(() => _error = 'File audio sumber tidak tersedia untuk diputar.');
      return;
    }
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      await _player.setPlaybackRate(_speed);
      await _player.setSourceDeviceFile(widget.audioPath!);
      _duration = await _player.getDuration();
      _positionSub = _player.onPositionChanged.listen((position) {
        if (!mounted) return;
        setState(() {
          _positionSeconds = position.inMilliseconds / 1000.0;
        });
      });
      _playerStateSub = _player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() {
          _playing = state == PlayerState.playing;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
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

  Future<void> _togglePlayback() async {
    if (widget.audioPath == null) return;
    try {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.setPlaybackRate(_speed);
        if (_positionSeconds > 0) {
          await _player.seek(Duration(milliseconds: (_positionSeconds * 1000).round()));
        }
        await _player.resume();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _seekTo(double seconds) async {
    if (widget.audioPath == null) return;
    try {
      await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
      if (!mounted) return;
      setState(() => _positionSeconds = seconds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final maxSeconds = (widget.durationSeconds > 0
            ? widget.durationSeconds
            : (_duration?.inMilliseconds ?? 0) / 1000.0)
        .toDouble()
        .clamp(1.0, double.infinity);

    // Find the active segment index based on current playback position
    final activeIndex = _positionSeconds > 0
        ? _segments.lastIndexWhere(
            (s) => s.timestamp <= _positionSeconds && (s.timestamp + s.duration) > _positionSeconds)
        : -1;

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
              activeSegmentIndex: activeIndex >= 0 ? activeIndex : null,
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
                if (_error != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Seek slider
                Row(
                  children: [
                    Text(_formatTime(_positionSeconds),
                      style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _positionSeconds.clamp(0.0, maxSeconds).toDouble(),
                        max: maxSeconds,
                        activeColor: colors.primary,
                        onChanged: widget.audioPath == null ? null : (v) => setState(() => _positionSeconds = v),
                        onChangeEnd: widget.audioPath == null ? null : _seekTo,
                      ),
                    ),
                    Text(_formatTime(maxSeconds),
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
                      onPressed: widget.audioPath == null ? null : _togglePlayback,
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
                          if (v != null) {
                            setState(() => _speed = v);
                            unawaited(_player.setPlaybackRate(v));
                          }
                        },
                      ),
                    ),
                  ],
                ),

                // Export button row
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_outlined, size: 16),
                      label: const Text('Export', style: TextStyle(fontSize: 13)),
                      onPressed: () => _exportTranscript(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Future<void> _exportTranscript(BuildContext context) async {
    // Bridge calls go through Riverpod providers
    // Build a temporary SessionSummary from current data
    final summary = SessionSummary(
      id: widget.title,
      title: widget.title,
      date: DateTime.now().toIso8601String().substring(0, 10),
      segmentsCount: _segments.length,
      segments: _segments,
      durationSeconds: widget.durationSeconds,
    );
    // Try to find RustBridge from ancestor provider
    if (!context.mounted) return;
    // Show export dialog using the stored segments
    final defaultDir = '/Users/\$USER/Documents/TrareonTranscribe';
    await showExportDialog(
      context,
      summary,
      bridge: RustBridgeMock(),
      defaultOutputDir: defaultDir,
    );
  }
}
