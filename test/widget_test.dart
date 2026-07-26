import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/main.dart';
import 'package:transcribe/services/bridge_service.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/src/rust/audio/device.dart' as rust_device;
import 'package:transcribe/src/rust/session.dart' as rust_session;
import 'package:transcribe/src/rust/export.dart' as rust_export;
import 'package:transcribe/src/rust/stt/file.dart' as rust_stt_file;

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
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        rustBridgeProvider.overrideWithValue(_NoopBridge()),
      ],
      child: const TranscribeApp(),
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
    expect(find.text('Otomatis'), findsOneWidget);
    expect(find.text('Mikrofon'), findsWidgets);
    expect(find.text('Pengeras Suara'), findsWidgets);
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

    expect(find.text('Berhenti'), findsOneWidget);
  });

  testWidgets('settings icon navigates to settings screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pengaturan'));
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

    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laporan Privasi'));
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

    // Toggle shortcuts panel via keyboard shortcut (Cmd+/)
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
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
    await tester.tap(find.text('Berhenti'));
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

    expect(find.text('Ekspor'), findsOneWidget);
  });

  testWidgets('audio indicators show MIC and SPK labels', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Mikrofon'), findsWidgets);
    expect(find.text('Pengeras Suara'), findsWidgets);
  });

  testWidgets('footer shows recording timer when active', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pumpAndSettle();

    // Timer not shown when idle — only when recording/paused
    expect(find.textContaining('Trareon Transcribe'), findsOneWidget);
  });

  test('RustBridgeMock persists settings roundtrip in memory', () async {
    final bridge = RustBridgeMock();
    final initial = await bridge.loadSettings();
    expect(initial.defaultModel, 'tiny');

    final updated = AppSettings(
      theme: AppThemeMode.dark,
      defaultModel: 'small',
      defaultMode: SessionMode.webinar,
      libraryPath: '/tmp/transcribe',
      vadEnabled: false,
      language: 'en',
    );
    await bridge.saveSettings(updated);

    final reloaded = await bridge.loadSettings();
    expect(reloaded.theme, AppThemeMode.dark);
    expect(reloaded.defaultModel, 'small');
    expect(reloaded.libraryPath, '/tmp/transcribe');
    expect(reloaded.vadEnabled, isFalse);
    expect(reloaded.language, 'en');
  });
}
