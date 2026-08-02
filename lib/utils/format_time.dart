/// Shared time-formatting helpers for Trareon Transcribe.
///
/// Eliminates the duplicated `_formatTime`/`_formatElapsed`/`_formatDuration`
/// functions that previously lived in `transcript_view.dart`,
/// `main_screen.dart`, `session_card.dart`, and
/// `transcript_player_screen.dart`.
library;

/// Format a [Duration] as a clock-style string, e.g. `5:02` or `1:23:45`.
///
/// Used for elapsed/recording timers and player position labels.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Format a seconds value as a bracketed timestamp, e.g. `[00:42]`.
///
/// Used inline in transcript text like `[00:42] teks`.
String formatTimestamp(double seconds) {
  final d = Duration(milliseconds: (seconds * 1000).round());
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '[$m:$s]';
}

/// Format a duration in seconds as a human-friendly Indonesian label,
/// e.g. `45 menit` or `1j 30m`.
///
/// Kept separate from [formatDuration] because the session-card duration
/// label uses a distinct non-clock format ("menit"/"j").
String formatDurationLabel(double seconds) {
  final h = (seconds / 3600).floor();
  final m = ((seconds % 3600) / 60).floor();
  if (h > 0) return '${h}j ${m}m';
  return '$m menit';
}
