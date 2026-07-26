import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/main.dart';
import 'package:trascribe/services/bridge_service.dart';
import 'package:trascribe/state/models.dart';
import 'package:trascribe/state/settings_model.dart';
import 'package:trascribe/src/rust/audio/device.dart' as rust_device;
import 'package:trascribe/src/rust/session.dart' as rust_session;
import 'package:trascribe/src/rust/export.dart' as rust_export;
import 'package:trascribe/src/rust/stt/file.dart' as rust_stt_file;

/// Timer-free test double
class _NoopBridge implements RustBridge {
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
    List<rust_export.ExportFormat> formats = const [],
  }) async {}
  @override
  Future<void> pauseSession(String sessionId) async {}
  @override
  Future<void> resumeSession(String sessionId) async {}
}

void main() {
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        rustBridgeProvider.overrideWithValue(_NoopBridge()),
        firstRunCompleteProvider.overrideWith((ref) => true),
      ],
      child: const TrascribeApp(),
    );
  }

  testWidgets('main screen renders mode selector and start button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Mulai'), findsOneWidget);
    expect(find.text('Webinar'), findsWidgets);
    expect(find.text('Rapat Online'), findsWidgets);
    expect(find.text('Rapat Offline'), findsWidgets);
  });

  testWidgets('starting a session switches button to Stop', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mulai'));
    await tester.pump();

    expect(find.text('Stop'), findsOneWidget);
  });

  testWidgets('settings icon navigates to settings screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    expect(find.text('Tema'), findsOneWidget);
  });

  testWidgets('settings screen navigates into Privacy Report', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Report'));
    await tester.pumpAndSettle();

    expect(find.text('0 network calls since launch'), findsOneWidget);
  });

  testWidgets('shortcuts icon toggles keyboard shortcuts panel', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Shortcuts'));
    await tester.pumpAndSettle();

    expect(find.text('Pintasan keyboard'), findsWidgets);
  });

  testWidgets('stop without segments does not show confirmation dialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mulai'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(find.text('Berhenti merekam?'), findsNothing);
    expect(find.text('Mulai'), findsOneWidget);
  });

  testWidgets('export button is visible', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Export'), findsOneWidget);
  });

  testWidgets('audio indicators show MIC and SPK labels', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('MIC'), findsWidgets);
    expect(find.text('SPK'), findsWidgets);
  });

  testWidgets('footer shows diarization info', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Diarisasi aktif'), findsOneWidget);
  });

  test('RustBridgeMock persists settings roundtrip in memory', () async {
    final bridge = RustBridgeMock();
    final initial = await bridge.loadSettings();
    expect(initial.defaultModel, 'tiny');

    final updated = AppSettings(
      theme: AppThemeMode.dark,
      defaultModel: 'small',
      defaultMode: SessionMode.webinar,
      libraryPath: '/tmp/trascribe',
      vadEnabled: false,
      language: 'en',
    );
    await bridge.saveSettings(updated);

    final reloaded = await bridge.loadSettings();
    expect(reloaded.theme, AppThemeMode.dark);
    expect(reloaded.defaultModel, 'small');
    expect(reloaded.libraryPath, '/tmp/trascribe');
    expect(reloaded.vadEnabled, isFalse);
    expect(reloaded.language, 'en');
  });
}
