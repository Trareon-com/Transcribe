// Copyright 2026 YSF Studio. Licensed under Privacy-Preserving Software License v1.0.
// SPDX-License-Identifier: PPSL
//
// Flight recorder — a privacy-conscious event logger for diagnosing
// session lifecycle issues WITHOUT recording audio or transcript content.
//
// Events recorded (metadata only):
//   - lifecycle transitions (start/pause/resume/stop)
//   - segment arrival rate (count + timing, NOT text)
//   - errors from the Rust bridge
//   - auto-stop triggers
//
// Explicitly NOT recorded:
//   - transcript text / segment content
//   - audio bytes
//   - window titles or app names
//   - any PII
//
// Logs are written as JSONL to a single rotating file under the app
// config directory. Old entries beyond [maxEntries] are trimmed on write.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FlightRecorder {
  FlightRecorder._();

  static final FlightRecorder instance = FlightRecorder._();

  static const String _fileName = 'flight_recorder.jsonl';
  static const int maxEntries = 5000;

  File? _file;
  int _writeCount = 0;
  bool _enabled = true;

  /// Lazily resolves the app-support directory and opens the log file.
  Future<File> _ensureFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_fileName');
    _file = file;
    return file;
  }

  /// Master switch — set false to disable all recording (defense in depth).
  void setEnabled(bool value) => _enabled = value;

  /// Test hook — point the recorder at a temp file (bypasses path_provider,
  /// which needs a plugin channel not available in unit tests).
  void useFile(File file) => _file = file;

  Future<void> _append(Map<String, Object?> event) async {
    if (!_enabled) return;
    try {
      final file = await _ensureFile();
      event['ts'] = DateTime.now().toIso8601String();
      await file.writeAsString(
        '${jsonEncode(event)}\n',
        mode: FileMode.append,
        flush: true,
      );
      _writeCount++;
      if (_writeCount >= 256) {
        _writeCount = 0;
        await _trim();
      }
    } catch (_) {
      // Flight recorder must never crash the app — swallow all errors.
    }
  }

  /// Keeps only the most recent [maxEntries] lines.
  Future<void> _trim() async {
    try {
      final file = await _ensureFile();
      if (!await file.exists()) return;
      final lines = await file.readAsLines();
      if (lines.length <= maxEntries) return;
      await file.writeAsString(
        '${lines.sublist(lines.length - maxEntries).join('\n')}\n',
        flush: true,
      );
    } catch (_) {}
  }

  // ── Event API ──────────────────────────────────────────────────────

  Future<void> logLifecycle({
    required String sessionId,
    required String from,
    required String to,
  }) =>
      _append({
        'type': 'lifecycle',
        'session': sessionId,
        'from': from,
        'to': to,
      });

  Future<void> logSegmentBatch({
    required String sessionId,
    required int batchSize,
    required int totalSegments,
    required int queueDepth,
  }) =>
      _append({
        'type': 'segments',
        'session': sessionId,
        'batch': batchSize,
        'total': totalSegments,
        'queue': queueDepth,
      });

  Future<void> logError({
    required String sessionId,
    required String source,
    required String message,
  }) =>
      _append({
        'type': 'error',
        'session': sessionId,
        'source': source,
        'message': message.substring(0, message.length.clamp(0, 500)),
      });

  Future<void> logAutoStop({
    required String sessionId,
    required int minutes,
  }) =>
      _append({
        'type': 'autostop',
        'session': sessionId,
        'minutes': minutes,
      });

  Future<void> logSystem({
    required String event,
    Map<String, Object?>? details,
  }) =>
      _append({
        'type': 'system',
        'event': event,
        ...?details,
      });

  /// Reads the current flight-recorder contents for diagnostics.
  /// Returns raw JSONL text.
  Future<String> readLog() async {
    try {
      final file = await _ensureFile();
      if (!await file.exists()) return '';
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// Clears the log. Used after a successful diagnostic session.
  Future<void> clearLog() async {
    try {
      final file = await _ensureFile();
      if (await file.exists()) {
        await file.writeAsString('', flush: true);
      }
    } catch (_) {}
  }
}
