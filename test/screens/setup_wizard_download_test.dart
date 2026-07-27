import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/screens/setup_wizard_screen.dart';
import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/src/rust/audio/device.dart';
import 'package:transcribe/src/rust/export.dart';
import 'package:transcribe/src/rust/session.dart';
import 'package:transcribe/src/rust/stt/file.dart';
import 'package:transcribe/state/models.dart';

class _NoDownloadBridge implements RustBridge {
  @override
  Future<void> downloadModel(String modelsDir, String modelId) {
    return Future<void>.value();
  }
  @override
  Stream<double> downloadProgress() => const Stream.empty();
  @override
  Future<String> startSession(SessionConfig config) async => 'mock';
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
  Future<List<SessionRecoverySnapshot>> listRecoverableSessions() async => [];
  @override
  Future<String> recoverSession(SessionRecoverySnapshot snapshot) async => 'mock';
  @override
  Future<AppSettings> loadSettings() async => AppSettings.defaults();
  @override
  Future<void> saveSettings(AppSettings settings) async {}
  @override
  Future<List<AudioDeviceInfo>> listAudioDevices() async => [];
  @override
  Future<List<AudioDeviceInfo>> listOutputAudioDevices() async => [];
  @override
  Future<String> detectFrontmostWindowTitle() async => '';
  @override
  Future<List<TranscribeFileResult>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
  }) async => [];
  @override
  Future<void> exportSession({
    required List<TranscriptSegment> segments,
    required String outputDir,
    required String title,
    List<ExportFormat> formats = const [],
  }) async {}
  @override
  void pauseSession(String sessionId) {}
  @override
  void resumeSession(String sessionId) {}
}

void main() {
  testWidgets('wizard shows download dialog when model is missing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(_NoDownloadBridge())],
        child: MaterialApp(
          home: SetupWizardScreen(onFinished: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Advance through spec detect
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Advance from model choice → triggers download since model is missing
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    // Download dialog should appear
    expect(find.textContaining('Mengunduh model'), findsOneWidget);
  });
}
