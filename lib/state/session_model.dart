import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import 'models.dart';
import 'settings_model.dart';

enum SessionLifecycle { idle, recording, stopped }

class SessionUiState {
  final SessionLifecycle lifecycle;
  final String? sessionId;
  final SessionConfig config;
  final List<TranscriptSegment> segments;

  const SessionUiState({
    required this.lifecycle,
    required this.config,
    this.sessionId,
    this.segments = const [],
  });

  SessionUiState copyWith({
    SessionLifecycle? lifecycle,
    String? sessionId,
    SessionConfig? config,
    List<TranscriptSegment>? segments,
  }) {
    return SessionUiState(
      lifecycle: lifecycle ?? this.lifecycle,
      sessionId: sessionId ?? this.sessionId,
      config: config ?? this.config,
      segments: segments ?? this.segments,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionUiState> {
  final RustBridge _bridge;
  StreamSubscription<TranscriptSegment>? _transcriptSub;

  SessionNotifier(this._bridge, SessionMode initialMode)
      : super(
          SessionUiState(
            lifecycle: SessionLifecycle.idle,
            config: SessionConfig.forMode(initialMode, 'models/ggml-tiny.bin'),
          ),
        );

  Future<void> start() async {
    final id = await _bridge.startSession(state.config);
    state = state.copyWith(
      lifecycle: SessionLifecycle.recording,
      sessionId: id,
      segments: [],
    );
    _transcriptSub = _bridge.transcriptStream(id).listen((segment) {
      state = state.copyWith(segments: [...state.segments, segment]);
    });
  }

  Future<void> stop() async {
    final id = state.sessionId;
    if (id == null) return;
    await _transcriptSub?.cancel();
    await _bridge.stopSession(id);
    state = state.copyWith(lifecycle: SessionLifecycle.stopped);
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

  void setMode(SessionMode mode) {
    state = state.copyWith(config: state.config.copyWith(mode: mode));
  }

  @override
  void dispose() {
    _transcriptSub?.cancel();
    super.dispose();
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionUiState>((ref) {
  final defaultMode = ref.watch(settingsProvider).defaultMode;
  return SessionNotifier(ref.watch(rustBridgeProvider), defaultMode);
});
