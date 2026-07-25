import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trascribe/services/bridge_service.dart';
import 'package:trascribe/state/models.dart';
import 'package:trascribe/state/session_model.dart';
import 'package:trascribe/state/settings_model.dart';
import 'package:trascribe/src/rust/audio/device.dart' as rust_device;
import 'package:trascribe/src/rust/session.dart' as rust_session;

class _NoopBridge implements RustBridge {
  final AppSettings settings;

  _NoopBridge({AppSettings? settings}) : settings = settings ?? AppSettings.defaults();

  @override
  Future<String> startSession(SessionConfig config) async => 'test-session';

  @override
  Future<void> stopSession(String sessionId) async {}

  @override
  Future<void> toggleMic(String sessionId, bool enabled) async {}

  @override
  Future<void> toggleSpeaker(String sessionId, bool enabled) async {}

  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) => const Stream.empty();

  @override
  Stream<VuLevel> vuMeterStream(String sessionId) => const Stream.empty();

  @override
  Future<List<rust_session.SessionRecoverySnapshot>> listRecoverableSessions() async => const [];

  @override
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot) async =>
      'test-session';

  @override
  Future<AppSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {}

  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {}

  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() async => const [];

  @override
  Future<String> detectFrontmostWindowTitle() async => '';
}

void main() {
  test('editTranscriptSegment updates only the selected segment', () {
    final notifier = SessionNotifier(
      _NoopBridge(),
      SessionMode.online,
      modelPathForId('tiny'),
    );
    notifier.state = notifier.state.copyWith(
        segments: const [
          TranscriptSegment(
            source: 'mic',
            speaker: 'MIC',
            text: 'satu',
            timestamp: 0,
            duration: 1,
            language: 'id',
            confidence: 0.9,
            isPartial: false,
          ),
          TranscriptSegment(
            source: 'spk',
            speaker: 'SPK',
            text: 'dua',
            timestamp: 1,
            duration: 1,
            language: 'id',
            confidence: 0.9,
            isPartial: false,
          ),
        ],
      );

    notifier.editTranscriptSegment(1, 'dua diperbarui');

    expect(notifier.state.segments.first.text, 'satu');
    expect(notifier.state.segments.last.text, 'dua diperbarui');
  });

  test('initial session config uses the provided model path', () {
    final notifier = SessionNotifier(
      _NoopBridge(),
      SessionMode.offline,
      modelPathForId('small'),
    );

    expect(notifier.state.config.modelPath, 'models/ggml-small.bin');
  });

  test('session provider syncs loaded settings while idle', () async {
    final bridge = _NoopBridge(
      settings: const AppSettings(
        theme: AppThemeMode.light,
        defaultModel: 'medium',
        defaultMode: SessionMode.webinar,
        libraryPath: '~/Documents/Trascribe',
        vadEnabled: true,
        echoDedupeEnabled: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [rustBridgeProvider.overrideWithValue(bridge)],
    );
    addTearDown(container.dispose);

    expect(container.read(sessionProvider).config.modelPath, 'models/ggml-tiny.bin');

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final session = container.read(sessionProvider);
    expect(session.config.modelPath, 'models/ggml-medium.bin');
    expect(session.config.mode, SessionMode.webinar);
  });
}
