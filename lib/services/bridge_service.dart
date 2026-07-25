import 'dart:async';
import 'dart:math';

import '../src/rust/api.dart' as rust_api;
import '../src/rust/audio.dart' as rust_audio;
import '../src/rust/settings.dart' as rust_settings;
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
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
}

class RustBridgeMock implements RustBridge {
  final _random = Random();
  final Map<String, StreamController<TranscriptSegment>> _transcriptControllers = {};
  final Map<String, StreamController<VuLevel>> _vuControllers = {};
  final Map<String, Timer> _timers = {};

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
  Future<AppSettings> loadSettings() async => AppSettings.defaults();

  @override
  Future<void> saveSettings(AppSettings settings) async {}
}

/// Real bridge backed by the flutter_rust_bridge-generated bindings in
/// `lib/src/rust/`. Requires `RustLib.init()` to have completed (see
/// `main()`). Converts between the hand-written Dart models in
/// `state/models.dart` and the generated types 1:1.
///
/// `transcriptStream`/`vuMeterStream` are not yet backed by real-time
/// data — `rust_core::api` doesn't expose a stream surface yet (the live
/// audio capture thread wiring itself is still hardware-dependent future
/// work, see ARCHITECTURE.md). They return empty streams so the UI degrades
/// gracefully rather than crashing.
class RustEngineBridge implements RustBridge {
  @override
  Future<String> startSession(SessionConfig config) {
    return rust_api.startSession(config: _toRustSessionConfig(config));
  }

  @override
  Future<void> stopSession(String sessionId) => rust_api.stopSession(sessionId: sessionId);

  @override
  Future<void> toggleMic(String sessionId, bool enabled) =>
      rust_api.toggleMic(sessionId: sessionId, enabled: enabled);

  @override
  Future<void> toggleSpeaker(String sessionId, bool enabled) =>
      rust_api.toggleSpeaker(sessionId: sessionId, enabled: enabled);

  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) => const Stream.empty();

  @override
  Stream<VuLevel> vuMeterStream(String sessionId) => const Stream.empty();

  @override
  Future<AppSettings> loadSettings() async {
    final settings = await rust_api.loadSettings();
    return _fromRustSettings(settings);
  }

  @override
  Future<void> saveSettings(AppSettings settings) {
    return rust_api.saveSettings(settings: _toRustSettings(settings));
  }

  rust_audio.SessionConfig _toRustSessionConfig(SessionConfig config) {
    return rust_audio.SessionConfig(
      micEnabled: config.micEnabled,
      speakerEnabled: config.speakerEnabled,
      mode: _toRustSessionMode(config.mode),
      modelPath: config.modelPath,
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
      echoDedupeEnabled: settings.echoDedupeEnabled,
      language: settings.language,
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
      echoDedupeEnabled: settings.echoDedupeEnabled,
      language: settings.language,
    );
  }
}
