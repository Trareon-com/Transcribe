import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/session_model.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;
import 'package:transcribe/src/rust/session.dart' as rust_session;
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/stt/file.dart' as rust_stt_file;

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
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() async => const [];

  @override
  Future<String> detectFrontmostWindowTitle() async => '';

  @override
  Stream<double> downloadProgress() => const Stream.empty();

  @override
  Future<List<rust_stt_file.TranscribeFileResult>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
  }) async => [];

  @override
  Future<void> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<rust_export.ExportFormat> formats = const [],
  }) async {}
  @override
  Future<void> pauseSession(String sessionId) async {}
  @override
  Future<void> resumeSession(String sessionId) async {}
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
    final tempDir = await Directory.systemTemp.createTemp('transcribe-session-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    File('${tempDir.path}/ggml-medium.bin').writeAsStringSync('stub');

    final bridge = _NoopBridge(
      settings: AppSettings(
        theme: AppThemeMode.light,
        defaultModel: 'medium',
        defaultMode: SessionMode.webinar,
        libraryPath: tempDir.path,
        vadEnabled: true,
        autoStopMinutes: 10,
      ),
    );
    final container = ProviderContainer(
      overrides: [rustBridgeProvider.overrideWithValue(bridge)],
    );
    addTearDown(container.dispose);

    // Initial state uses AppSettings.defaults() (model='tiny')
    expect(container.read(sessionProvider).config.modelPath,
        endsWith('models/ggml-tiny.bin'));

    SessionUiState session = container.read(sessionProvider);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      session = container.read(sessionProvider);
      if (session.config.modelPath == 'models/ggml-medium.bin') break;
    }

    expect(session.config.modelPath, '${tempDir.path}/ggml-medium.bin');
    expect(session.config.mode, SessionMode.webinar);
  });
}
