import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import '../src/rust/audio.dart' as rust_audio;
import '../src/rust/session.dart' as rust_session;
import 'models.dart';
import 'settings_model.dart';

enum SessionLifecycle { idle, recording, paused, stopped }

class SessionUiState {
  final SessionLifecycle lifecycle;
  final String? sessionId;
  final SessionConfig config;
  final List<TranscriptSegment> segments;
  final String sessionTitle;

  const SessionUiState({
    required this.lifecycle,
    required this.config,
    this.sessionId,
    this.segments = const [],
    this.sessionTitle = '',
  });

  /// Average confidence across current segments, or null if there are none
  /// yet — callers should show a placeholder rather than a fabricated value.
  double? get averageConfidence {
    if (segments.isEmpty) return null;
    final sum = segments.fold<double>(0, (acc, s) => acc + s.confidence);
    return sum / segments.length;
  }

  SessionUiState copyWith({
    SessionLifecycle? lifecycle,
    String? sessionId,
    SessionConfig? config,
    List<TranscriptSegment>? segments,
    String? sessionTitle,
  }) {
    return SessionUiState(
      lifecycle: lifecycle ?? this.lifecycle,
      sessionId: sessionId ?? this.sessionId,
      config: config ?? this.config,
      segments: segments ?? this.segments,
      sessionTitle: sessionTitle ?? this.sessionTitle,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionUiState> {
  final RustBridge _bridge;
  StreamSubscription<TranscriptSegment>? _transcriptSub;
  Timer? _autoStopTimer;
  int? _autoStopMinutes;
  String _libraryPath = '~/Documents/Trascribe';

  SessionNotifier(this._bridge, SessionMode initialMode, String initialModelPath)
      : super(
          SessionUiState(
            lifecycle: SessionLifecycle.idle,
            config: SessionConfig.forMode(
              initialMode,
              initialModelPath,
            ),
          ),
        );

  void _resetAutoStopTimer() {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    final minutes = _autoStopMinutes;
    if (minutes == null || minutes <= 0) return;
    if (state.lifecycle != SessionLifecycle.recording) return;
    _autoStopTimer = Timer(Duration(minutes: minutes), () {
      _autoStopTimer = null;
      if (state.lifecycle == SessionLifecycle.recording) {
        stop();
      }
    });
  }

  static bool _isBlankAudio(TranscriptSegment s) =>
      s.text.trim() == '[BLANK_AUDIO]';

  void _onTranscriptSegment(TranscriptSegment segment) {
    if (_isBlankAudio(segment)) return;
    state = state.copyWith(segments: [...state.segments, segment]);
    _resetAutoStopTimer();
  }

  void _subscribeToLiveStreams(String sessionId) {
    _transcriptSub = _bridge.transcriptStream(sessionId).listen(_onTranscriptSegment);
  }

  void _cancelLiveStreams() {
    _transcriptSub?.cancel();
    _transcriptSub = null;
  }

  void seedRecovery(rust_session.SessionRecoverySnapshot snapshot) {
    final recovered = SessionConfig(
      micEnabled: snapshot.config.micEnabled,
      speakerEnabled: snapshot.config.speakerEnabled,
      mode: switch (snapshot.config.mode) {
        rust_audio.SessionMode.webinar => SessionMode.webinar,
        rust_audio.SessionMode.online => SessionMode.online,
        rust_audio.SessionMode.offline => SessionMode.offline,
      },
      modelPath: snapshot.config.modelPath,
      vadEnabled: snapshot.config.vadEnabled,
    );
    state = state.copyWith(config: recovered);
  }

  Future<void> recoverFromSnapshot(rust_session.SessionRecoverySnapshot snapshot) async {
    seedRecovery(snapshot);
    final id = await _bridge.recoverSession(snapshot);
    state = state.copyWith(
      lifecycle: SessionLifecycle.recording,
      sessionId: id,
      segments: [],
    );
    _subscribeToLiveStreams(id);
    _resetAutoStopTimer();
  }

  Future<void> start() async {
    // Guard against double-start: if already recording/paused, ignore.
    if (state.lifecycle == SessionLifecycle.recording ||
        state.lifecycle == SessionLifecycle.paused) { return; }
    // Model existence is checked by the Rust side's own resolve_model_path(),
    // which handles tilde expansion, sandbox paths, and multiple search
    // locations. The old File.existsSync() check here was unreliable because
    // modelPath can be a relative path (fallback from modelPathForId) that
    // doesn't resolve against the Flutter app bundle's CWD, or contain an
    // unexpanded '~' in the library path — producing false-positive "model
    // tidak ditemukan" errors even when the model file exists.
    // Auto-detect frontmost window title as default session name.
    final detected = await _bridge.detectFrontmostWindowTitle();
    // start_capture() on the Rust side treats a null device id as "setup not
    // completed" and skips spawning the capture thread entirely — so a
    // concrete device name must be resolved here, or mic/speaker audio is
    // silently never captured regardless of the mic/speaker toggles.
    final configWithDevices = await _resolveDevices(state.config);
    state = state.copyWith(config: configWithDevices);
    final id = await _bridge.startSession(state.config);
    state = state.copyWith(
      lifecycle: SessionLifecycle.recording,
      sessionId: id,
      segments: [],
      sessionTitle: detected.isNotEmpty ? detected : state.sessionTitle,
    );
    _subscribeToLiveStreams(id);
    _resetAutoStopTimer();
  }

  /// Resolves concrete mic/speaker device names when the config doesn't
  /// already carry one. Mirrors the setup wizard's own default-selection
  /// heuristic: system default input device for mic, first loopback-looking
  /// output device (BlackHole/WASAPI loopback) for speaker.
  Future<SessionConfig> _resolveDevices(SessionConfig config) async {
    var micDeviceId = config.micDeviceId;
    var speakerDeviceId = config.speakerDeviceId;
    if (micDeviceId == null && config.micEnabled) {
      final inputs = await _bridge.listAudioDevices();
      if (inputs.isNotEmpty) {
        micDeviceId = inputs.first.name;
      }
    }
    if (speakerDeviceId == null && config.speakerEnabled) {
      final outputs = await _bridge.listOutputAudioDevices();
      if (outputs.isNotEmpty) {
        speakerDeviceId = outputs
            .firstWhere(
              (d) => d.name.toLowerCase().contains('blackhole') ||
                  d.name.toLowerCase().contains('loopback'),
              orElse: () => outputs.first,
            )
            .name;
      }
      // Fallback: search listAudioDevices() for BlackHole/loopback too
      if (speakerDeviceId == null) {
        final inputs = await _bridge.listAudioDevices();
        if (inputs.isNotEmpty) {
          speakerDeviceId = inputs
              .firstWhere(
                (d) => d.name.toLowerCase().contains('blackhole') ||
                    d.name.toLowerCase().contains('loopback'),
                orElse: () => inputs.first,
              )
              .name;
        }
      }
    }
    return config.copyWith(micDeviceId: micDeviceId, speakerDeviceId: speakerDeviceId);
  }

  Future<void> stop() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    final id = state.sessionId;
    if (id == null) return;
    _cancelLiveStreams();
    await _bridge.stopSession(id);
    state = state.copyWith(lifecycle: SessionLifecycle.stopped);
    final segments = state.segments;
    if (segments.isNotEmpty) {
      final title = state.sessionTitle.isNotEmpty
          ? state.sessionTitle
          : 'Sesi ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}';
      final outputDir = resolveTilde(_libraryPath);
      await _bridge.exportSession(
        segments: segments,
        outputDir: outputDir,
        title: title,
      );
    }
  }

  /// Pauses live transcript updates without tearing down the session —
  /// distinct from stop(), which ends it entirely (PP: pause/resume
  /// recording, not just start/stop). Cancellation of the old stream
  /// subscription is fire-and-forget: the UI toggle doesn't await pause(),
  /// so lifecycle must flip synchronously rather than after an async gap.
  void pause() {
    if (state.lifecycle != SessionLifecycle.recording) return;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _cancelLiveStreams();
    final id = state.sessionId;
    if (id != null) _bridge.pauseSession(id);
    state = state.copyWith(lifecycle: SessionLifecycle.paused);
  }

  void resume() {
    final id = state.sessionId;
    if (id == null || state.lifecycle != SessionLifecycle.paused) return;
    _bridge.resumeSession(id);
    _subscribeToLiveStreams(id);
    _resetAutoStopTimer();
    state = state.copyWith(lifecycle: SessionLifecycle.recording);
  }

  Future<void> toggleMic(bool enabled) async {
    final id = state.sessionId;
    state = state.copyWith(config: state.config.copyWith(micEnabled: enabled));
    if (id != null) await _bridge.toggleMic(id, enabled);
  }

  Future<void> toggleSpeaker(bool enabled) async {
    final id = state.sessionId;
    state = state.copyWith(config: state.config.copyWith(speakerEnabled: enabled));
    if (id != null) await _bridge.toggleSpeaker(id, enabled);
  }

  void editTranscriptSegment(int index, String newText) {
    if (index < 0 || index >= state.segments.length) return;
    final edited = [...state.segments];
    edited[index] = edited[index].copyWith(text: newText);
    state = state.copyWith(segments: edited);
  }

  void setMode(SessionMode mode) {
    // Update mode AND apply mode's default mic/speaker toggles
    // (Blueprint: Webinar=Mic OFF/SPK ON, Online=Both ON, Offline=Mic ON/SPK OFF)
    final (mic, speaker) = mode.defaultToggles;
    state = state.copyWith(
      config: state.config.copyWith(
        mode: mode,
        micEnabled: mic,
        speakerEnabled: speaker,
      ),
    );
  }

  void syncDefaultSettings(AppSettings settings) {
    _libraryPath = settings.libraryPath;
    if (state.lifecycle == SessionLifecycle.recording ||
        state.lifecycle == SessionLifecycle.paused) {
      return;
    }
    _autoStopMinutes = settings.autoStopMinutes;
    final (mic, speaker) = settings.defaultMode.defaultToggles;
    state = state.copyWith(
      config: SessionConfig(
        micEnabled: mic,
        speakerEnabled: speaker,
        mode: settings.defaultMode,
        modelPath: modelPathForId(settings.defaultModel, libraryPath: settings.libraryPath),
        vadEnabled: settings.vadEnabled,
      ),
    );
  }

  void setTitle(String title) {
    state = state.copyWith(sessionTitle: title);
  }

  void updateAutoStopMinutes(int? minutes) {
    _autoStopMinutes = minutes;
    if (state.lifecycle == SessionLifecycle.recording) {
      _resetAutoStopTimer();
    }
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _cancelLiveStreams();
    super.dispose();
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionUiState>((ref) {
  // Use ref.read (not watch) — watching would recreate the SessionNotifier on
  // every settings change, destroying the active session (transcript subs,
  // timers, segments).  ref.listen below handles updates reactively.
  final settings = ref.read(settingsProvider);
  final notifier = SessionNotifier(
    ref.read(rustBridgeProvider),
    settings.defaultMode,
    modelPathForId(settings.defaultModel, libraryPath: settings.libraryPath),
  );
  notifier.syncDefaultSettings(settings);
  ref.listen<AppSettings>(settingsProvider, (previous, next) {
    notifier.syncDefaultSettings(next);
    if (previous?.autoStopMinutes != next.autoStopMinutes) {
      notifier.updateAutoStopMinutes(next.autoStopMinutes);
    }
  });
  return notifier;
});
