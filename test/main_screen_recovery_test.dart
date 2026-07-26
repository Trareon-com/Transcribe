import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/main.dart';
import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/src/rust/audio.dart' as rust_audio;
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;
import 'package:transcribe/src/rust/session.dart' as rust_session;
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/stt/file.dart' as rust_stt_file;

class _RecoveryBridge implements RustBridge {
  List<rust_session.SessionRecoverySnapshot> recoveries = const [];

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
  Future<List<rust_session.SessionRecoverySnapshot>> listRecoverableSessions() async => recoveries;
  @override
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot) async => 'test-session';
  @override
  Future<AppSettings> loadSettings() async => AppSettings.defaults();
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

void main() {
  testWidgets('recovery banner shows when sessions are recoverable', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = _RecoveryBridge();
    final snapshot = rust_session.SessionRecoverySnapshot(
      sessionId: 'crash-1',
      config: rust_audio.SessionConfig(
        micEnabled: true,
        speakerEnabled: false,
        mode: rust_audio.SessionMode.offline,
        modelPath: 'models/tiny.gguf',
        vadEnabled: true,
        sampleRate: 16000,
        chunkDurationSecs: 30,
      ),
      startedAtUnixMs: BigInt.zero,
      lastSplitAtUnixMs: BigInt.zero,
      segmentsCount: 1,
    );

    bridge.recoveries = [snapshot];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rustBridgeProvider.overrideWithValue(bridge),
        ],
        child: const MaterialApp(home: TranscribeApp()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('sesi yang bisa dipulihkan'), findsOneWidget);
    expect(find.text('Pulihkan'), findsOneWidget);
  });
}
