import 'dart:async';
import 'dart:io';

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
  final double micLevel;
  final double speakerLevel;

  const SessionUiState({
    required this.lifecycle,
    required this.config,
    this.sessionId,
    this.segments = const [],
    this.sessionTitle = '',
    this.micLevel = 0.0,
    this.speakerLevel = 0.0,
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
    double? micLevel,
    double? speakerLevel,
  }) {
    return SessionUiState(
      lifecycle: lifecycle ?? this.lifecycle,
      sessionId: sessionId ?? this.sessionId,
      config: config ?? this.config,
      segments: segments ?? this.segments,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      micLevel: micLevel ?? this.micLevel,
      speakerLevel: speakerLevel ?? this.speakerLevel,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionUiState> {
  final RustBridge _bridge;
  StreamSubscription<TranscriptSegment>? _transcriptSub;
  StreamSubscription<VuLevel>? _vuSub;
  Timer? _autoStopTimer;
  int? _autoStopMinutes;

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

  void _onTranscriptSegment(TranscriptSegment segment) {
    state = state.copyWith(segments: [...state.segments, segment]);
    _resetAutoStopTimer();
  }

  void _onVuLevel(VuLevel level) {
    state = state.copyWith(micLevel: level.micLevel, speakerLevel: level.speakerLevel);
  }

  void _subscribeToLiveStreams(String sessionId) {
    _transcriptSub = _bridge.transcriptStream(sessionId).listen(_onTranscriptSegment);
    _vuSub = _bridge.vuMeterStream(sessionId).listen(_onVuLevel);
  }

  void _cancelLiveStreams() {
    _transcriptSub?.cancel();
    _transcriptSub = null;
    _vuSub?.cancel();
    _vuSub = null;
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
    // Fail with a clear, catchable error rather than letting the FRB call
    // throw a raw "model file not found" exception with no UI handling —
    // this previously crashed session start unhandled whenever the
    // configured default model (e.g. from stale persisted settings) wasn't
    // actually downloaded.
    if (!File(state.config.modelPath).existsSync()) {
      throw StateError(
        'Model tidak ditemukan di ${state.config.modelPath}. '
        'Unduh model lewat Setup Wizard terlebih dahulu.',
      );
    }
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
        micDeviceId = inputs.firstWhere((d) => d.isDefault, orElse: () => inputs.first).name;
      }
    }
    if (speakerDeviceId == null && config.speakerEnabled) {
      final outputs = await _bridge.listOutputAudioDevices();
      if (outputs.isNotEmpty) {
        speakerDeviceId = outputs
            .firstWhere(
              (d) => d.name.toLowerCase().contains('blackhole') ||
                  d.name.toLowerCase().contains('loopback'),
              orElse: () => outputs.firstWhere((d) => d.isDefault, orElse: () => outputs.first),
            )
            .name;
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
    state = state.copyWith(
      lifecycle: SessionLifecycle.stopped,
      micLevel: 0.0,
      speakerLevel: 0.0,
    );
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
    state = state.copyWith(lifecycle: SessionLifecycle.paused, micLevel: 0.0, speakerLevel: 0.0);
  }

  void resume() {
    final id = state.sessionId;
    if (id == null || state.lifecycle != SessionLifecycle.paused) return;
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
    if (state.lifecycle == SessionLifecycle.recording ||
        state.lifecycle == SessionLifecycle.paused) {
      return;
    }
    _autoStopMinutes = settings.autoStopMinutes;
    state = state.copyWith(
      config: SessionConfig.forMode(
        settings.defaultMode,
        modelPathForId(settings.defaultModel, libraryPath: settings.libraryPath),
      ),
    );
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
