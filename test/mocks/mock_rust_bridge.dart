import 'dart:async';

import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/src/rust/audio/device.dart';
import 'package:transcribe/src/rust/export.dart';
import 'package:transcribe/src/rust/session.dart';
import 'package:transcribe/src/rust/stt/file.dart';
import 'package:transcribe/state/models.dart';

class MockRustBridge implements RustBridge {
  final _progressController = StreamController<double>.broadcast();

  @override
  Stream<double> downloadProgress() => _progressController.stream;

  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {
    for (var i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      _progressController.add(i / 10.0);
    }
  }

  @override
  Future<String> startSession(SessionConfig config) async => 'mock';
  @override
  Future<void> stopSession(String sessionId) async {}
  @override
  Future<void> toggleMic(String sessionId, bool enabled) async {}
  @override
  Future<void> toggleSpeaker(String sessionId, bool enabled) async {}
  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) =>
      const Stream.empty();
  @override
  Stream<VuLevel> vuMeterStream(String sessionId) => const Stream.empty();
  @override
  Future<List<SessionRecoverySnapshot>> listRecoverableSessions() async => [];
  @override
  Future<String> recoverSession(SessionRecoverySnapshot snapshot) async =>
      'mock';
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
  }) async =>
      [];
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
