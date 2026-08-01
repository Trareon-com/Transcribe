import 'dart:async';
import 'dart:io' show Process;
import 'dart:math';
import 'dart:typed_data';

import '../src/rust/api.dart' as rust_api;
import '../src/rust/audio.dart' as rust_audio;
import '../src/rust/audio/device.dart' as rust_device;
import '../src/rust/export.dart' as rust_export;
import '../src/rust/session.dart' as rust_session;
import '../src/rust/settings.dart' as rust_settings;
import '../src/rust/stt/file.dart' as rust_stt_file;
import '../state/models.dart';

/// Abstraction over the Rust engine, callable from Dart. [RustEngineBridge]
/// is the real flutter_rust_bridge-backed implementation; [RustBridgeMock]
/// is a timer-driven stand-in used by default in tests and available for
/// UI work that doesn't need a live Rust build.
abstract class RustBridge {
  Future<String> startSession(SessionConfig config);
  Future<void> stopSession(String sessionId);
  Future<void> toggleMic(String sessionId, bool enabled);
  Future<void> toggleSpeaker(String sessionId, bool enabled);
  Stream<TranscriptSegment> transcriptStream(String sessionId);
  Stream<VuLevel> vuMeterStream(String sessionId);
  Future<List<rust_session.SessionRecoverySnapshot>> listRecoverableSessions();
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot);
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<void> downloadModel(String modelsDir, String modelId);
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices();
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices();

  /// On macOS, returns the title of the frontmost window (e.g. a browser tab
  /// or meeting app name) via AppleScript. Falls back to empty string on
  /// other platforms or if detection fails.
  Future<String> detectFrontmostWindowTitle();

  /// Polls download progress for an active model download.
  /// Returns a stream of 0.0–1.0 ratios. Completes when progress reaches 1.0.
  /// The caller must start the download via [downloadModel] first.
  Stream<double> downloadProgress();

  /// Transcribe a batch of audio/video files using the given model.
  /// Returns a list of transcription results, one per file.
  Future<List<rust_stt_file.TranscribeFileResult>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
  });

  /// Writes [segments] to `outputDir/<sanitized title>/` in the requested
  /// [formats]. Each format is a member of [rust_export.ExportFormat].
  /// Defaults to [markdown, txt, json] when empty.
  Future<void> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [
      rust_export.ExportFormat.markdown,
      rust_export.ExportFormat.txt,
      rust_export.ExportFormat.json,
    ],
  });

  /// Prevents transcript and VU events from being forwarded to the Dart
  /// stream controllers during a pause. The Rust-side poll keeps draining the
  /// mpsc channel (preventing overflow) but events are silently discarded.
  void pauseSession(String sessionId);

  /// Resumes event forwarding for a previously-paused session.
  void resumeSession(String sessionId);
}

class RustBridgeMock implements RustBridge {
  final _random = Random();
  final Map<String, StreamController<TranscriptSegment>> _transcriptControllers = {};
  final Map<String, StreamController<VuLevel>> _vuControllers = {};
  final Map<String, Timer> _timers = {};
  AppSettings _settings = AppSettings.defaults();

  @override
  Future<String> startSession(SessionConfig config) async {
    final id = 'mock-session-${DateTime.now().millisecondsSinceEpoch}';
    final transcriptController = StreamController<TranscriptSegment>.broadcast();
    final vuController = StreamController<VuLevel>.broadcast();
    _transcriptControllers[id] = transcriptController;
    _vuControllers[id] = vuController;

    var elapsed = 0.0;
    _timers[id] = Timer.periodic(const Duration(milliseconds: 500), (_) {
      elapsed += 0.5;
      vuController.add(
        VuLevel(micLevel: _random.nextDouble(), speakerLevel: _random.nextDouble()),
      );
      if (elapsed.toInt() % 3 == 0) {
        transcriptController.add(
          TranscriptSegment(
            source: config.micEnabled ? 'mic' : 'spk',
            speaker: config.micEnabled ? 'MIC' : 'SPK',
            text: 'Contoh transkrip pada detik ke-${elapsed.toInt()}.',
            timestamp: elapsed,
            duration: 2.0,
            language: 'id',
            confidence: 0.92,
            isPartial: false,
          ),
        );
      }
    });

    return id;
  }

  @override
  Future<void> stopSession(String sessionId) async {
    _timers.remove(sessionId)?.cancel();
    await _transcriptControllers.remove(sessionId)?.close();
    await _vuControllers.remove(sessionId)?.close();
  }

  @override
  Future<void> toggleMic(String sessionId, bool enabled) async {}

  @override
  Future<void> toggleSpeaker(String sessionId, bool enabled) async {}

  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) {
    return _transcriptControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Stream<VuLevel> vuMeterStream(String sessionId) {
    return _vuControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Future<List<rust_session.SessionRecoverySnapshot>> listRecoverableSessions() async =>
      const [];

  @override
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot) async {
    return startSession(
      SessionConfig(
        micEnabled: snapshot.config.micEnabled,
        speakerEnabled: snapshot.config.speakerEnabled,
        mode: switch (snapshot.config.mode) {
          rust_audio.SessionMode.webinar => SessionMode.webinar,
          rust_audio.SessionMode.online => SessionMode.online,
          rust_audio.SessionMode.offline => SessionMode.offline,
        },
        modelPath: snapshot.config.modelPath,
        vadEnabled: snapshot.config.vadEnabled,
      ),
    );
  }

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {}

  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() async => [
        rust_device.AudioDeviceInfo(
          name: 'Built-in Microphone',
          deviceId: 'mic-1',
          isDefault: true,
          channels: 1,
          sampleRates: Uint32List.fromList([16000, 44100, 48000]),
        ),
      ];

  @override
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() async => [
        rust_device.AudioDeviceInfo(
          name: 'Built-in Speakers',
          deviceId: 'spk-1',
          isDefault: true,
          channels: 2,
          sampleRates: Uint32List.fromList([16000, 44100, 48000]),
        ),
        rust_device.AudioDeviceInfo(
          name: 'BlackHole 2ch',
          deviceId: 'spk-2',
          isDefault: false,
          channels: 2,
          sampleRates: Uint32List.fromList([16000, 44100, 48000]),
        ),
      ];

  @override
  Future<String> detectFrontmostWindowTitle() async => ''; // Mock: no real window detection

  @override
  Stream<double> downloadProgress() =>
      Stream.periodic(const Duration(milliseconds: 300), (i) => (i + 1) / 10.0).take(10);

  @override
  Future<List<rust_stt_file.TranscribeFileResult>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
  }) async => []; // Mock: returns empty results

  @override
  Future<void> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [
      rust_export.ExportFormat.markdown,
      rust_export.ExportFormat.txt,
      rust_export.ExportFormat.json,
    ],
  }) async {}

  @override
  void pauseSession(String sessionId) {}

  @override
  void resumeSession(String sessionId) {}
}

/// Real bridge backed by the flutter_rust_bridge-generated bindings in
/// `lib/src/rust/`. Requires `RustLib.init()` to have completed (see
/// `main()`). Converts between the hand-written Dart models in
/// `state/models.dart` and the generated types 1:1.
///
class RustEngineBridge implements RustBridge {
  final Map<String, StreamController<TranscriptSegment>> _transcriptControllers = {};
  final Map<String, StreamController<VuLevel>> _vuControllers = {};
  final Map<String, Timer> _pollTimers = {};
  final Set<String> _polling = {};
  final Set<String> _pausedSessions = {};

  @override
  Future<String> startSession(SessionConfig config) async {
    final id = await rust_api.startSession(config: _toRustSessionConfig(config));
    _transcriptControllers[id] = StreamController<TranscriptSegment>.broadcast();
    _vuControllers[id] = StreamController<VuLevel>.broadcast();
    _pollTimers[id] = Timer.periodic(const Duration(milliseconds: 200), (_) => _poll(id));
    return id;
  }

  @override
  Future<void> stopSession(String sessionId) async {
    _pollTimers.remove(sessionId)?.cancel();
    _polling.remove(sessionId);
    _pausedSessions.remove(sessionId);
    await rust_api.stopSession(sessionId: sessionId);
    await _transcriptControllers.remove(sessionId)?.close();
    await _vuControllers.remove(sessionId)?.close();
  }

  @override
  void pauseSession(String sessionId) => _pausedSessions.add(sessionId);

  @override
  void resumeSession(String sessionId) => _pausedSessions.remove(sessionId);

  @override
  Future<void> toggleMic(String sessionId, bool enabled) =>
      rust_api.toggleMic(sessionId: sessionId, enabled: enabled);

  @override
  Future<void> toggleSpeaker(String sessionId, bool enabled) =>
      rust_api.toggleSpeaker(sessionId: sessionId, enabled: enabled);

  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) {
    return _transcriptControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Stream<VuLevel> vuMeterStream(String sessionId) {
    return _vuControllers[sessionId]?.stream ?? const Stream.empty();
  }

  @override
  Future<List<rust_session.SessionRecoverySnapshot>> listRecoverableSessions() =>
      rust_api.listRecoverableSessions();

  @override
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot) =>
      rust_api.recoverSession(snapshot: snapshot);

  Future<void> _poll(String sessionId) async {
    if (!_polling.add(sessionId)) return;
    try {
      final events = await rust_session.pollEvents(sessionId: sessionId);
      // Always drain events even when paused — this prevents the Rust mpsc
      // channel from filling up and blocking capture threads. Events are
      // simply not forwarded to the Dart stream controllers.
      final paused = _pausedSessions.contains(sessionId);
      var micLevel = 0.0;
      var speakerLevel = 0.0;
      var hasVu = false;
      for (final event in events) {
        event.when(
          transcript: (segment) {
            if (!paused) _transcriptControllers[sessionId]?.add(_fromRustSegment(segment));
          },
          vu: (source, level) {
            if (!paused) {
              hasVu = true;
              if (source == 'mic') { micLevel = level; }
              else if (source == 'spk') { speakerLevel = level; }
            }
          },
        );
      }
      if (hasVu) {
        _vuControllers[sessionId]?.add(VuLevel(micLevel: micLevel, speakerLevel: speakerLevel));
      }
    } on Object catch (_) {
      // Session shutdown races with the 200ms poll timer are expected.
    } finally {
      _polling.remove(sessionId);
    }
  }

  TranscriptSegment _fromRustSegment(rust_export.Segment segment) {
    return TranscriptSegment(
      source: segment.source,
      speaker: segment.speaker,
      text: segment.text,
      timestamp: segment.timestamp,
      duration: segment.duration,
      language: segment.language,
      confidence: segment.confidence,
      isPartial: segment.isPartial,
    );
  }

  @override
  Future<AppSettings> loadSettings() async {
    final settings = await rust_api.loadSettings();
    return _fromRustSettings(settings);
  }

  @override
  Future<void> saveSettings(AppSettings settings) {
    return rust_api.saveSettings(settings: _toRustSettings(settings));
  }

  @override
  Future<void> downloadModel(String modelsDir, String modelId) =>
      rust_api.downloadModel(modelsDir: modelsDir, modelId: modelId);

  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() => rust_api.listAudioDevices();

  @override
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() =>
      rust_device.listOutputDevices();

  /// Detects the frontmost window title on macOS by calling osascript.
  /// Gracefully returns empty string on failure or non-macOS platforms.
  @override
  Future<String> detectFrontmostWindowTitle() async {
    try {
      final result = await Process.run(
        'osascript',
        [
          '-e',
          'tell application "System Events" to get title of first window of (first process whose frontmost is true)',
        ],
      );
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } on Object {
      // Graceful fallback — window detection is non-critical.
    }
    return '';
  }

  @override
  Stream<double> downloadProgress() {
    final controller = StreamController<double>();
    Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      final progress = await rust_api.getDownloadProgress();
      if (progress == null) return;
      final downloaded = progress.$1;
      final total = progress.$2;
      if (total == BigInt.zero) return;
      final ratio = downloaded.toDouble() / total.toDouble();
      controller.add(ratio);
      if (ratio >= 1.0) {
        timer.cancel();
        controller.close();
      }
    });
    return controller.stream;
  }

  @override
  Future<List<rust_stt_file.TranscribeFileResult>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
  }) =>
      rust_api.transcribeFilesBatch(
        modelPath: modelPath,
        files: files,
        language: language,
      );

  @override
  Future<void> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [
      rust_export.ExportFormat.markdown,
      rust_export.ExportFormat.txt,
      rust_export.ExportFormat.json,
    ],
  }) async {
    await rust_api.exportSession(
      segments: segments
          .map(
            (s) => rust_export.Segment(
              source: s.source,
              speaker: s.speaker,
              text: s.text,
              timestamp: s.timestamp,
              duration: s.duration,
              language: s.language,
              confidence: s.confidence,
              isPartial: s.isPartial,
            ),
          )
          .toList(),
      formats: formats,
      outputDir: outputDir,
      title: title,
    );
  }

  rust_audio.SessionConfig _toRustSessionConfig(SessionConfig config) {
    return rust_audio.SessionConfig(
      micEnabled: config.micEnabled,
      speakerEnabled: config.speakerEnabled,
      mode: _toRustSessionMode(config.mode),
      micDeviceId: config.micDeviceId,
      speakerDeviceId: config.speakerDeviceId,
      modelPath: config.modelPath,
      refineModelPath: config.refineModelPath,
      vadEnabled: config.vadEnabled,
      sampleRate: 16000,
      chunkDurationSecs: 30,
    );
  }

  rust_audio.SessionMode _toRustSessionMode(SessionMode mode) => switch (mode) {
    SessionMode.webinar => rust_audio.SessionMode.webinar,
    SessionMode.online => rust_audio.SessionMode.online,
    SessionMode.offline => rust_audio.SessionMode.offline,
  };

  SessionMode _fromRustSessionMode(rust_audio.SessionMode mode) => switch (mode) {
    rust_audio.SessionMode.webinar => SessionMode.webinar,
    rust_audio.SessionMode.online => SessionMode.online,
    rust_audio.SessionMode.offline => SessionMode.offline,
  };

  AppSettings _fromRustSettings(rust_settings.AppSettings settings) {
    return AppSettings(
      // Rust-side Theme has no "system" variant (a UI-only concept);
      // default to light rather than lose information silently.
      theme: settings.theme == rust_settings.Theme.dark
          ? AppThemeMode.dark
          : AppThemeMode.light,
      defaultModel: settings.defaultModel,
      defaultMode: _fromRustSessionMode(settings.defaultMode),
      libraryPath: settings.libraryPath,
      vadEnabled: settings.vadEnabled,
      language: settings.language,
      // autoStopMinutes is Dart-only; defaults to null (disabled) on load
      autoStopMinutes: null,
    );
  }

  rust_settings.AppSettings _toRustSettings(AppSettings settings) {
    return rust_settings.AppSettings(
      theme: settings.theme == AppThemeMode.dark
          ? rust_settings.Theme.dark
          : rust_settings.Theme.light,
      defaultModel: settings.defaultModel,
      defaultMode: _toRustSessionMode(settings.defaultMode),
      libraryPath: settings.libraryPath,
      alwaysOnTop: false,
      autoSaveIntervalSecs: 10,
      vadEnabled: settings.vadEnabled,
      // echoDedupeEnabled is mode-determined in Rust; always persist true
      echoDedupeEnabled: true,
      language: settings.language,
    );
  }
}
