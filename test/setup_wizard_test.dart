import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/screens/setup_wizard_screen.dart';
import 'package:trascribe/services/bridge_service.dart';
import 'package:trascribe/state/models.dart';
import 'package:trascribe/state/privacy_report_model.dart';
import 'package:trascribe/state/settings_model.dart';
import 'package:trascribe/src/rust/audio/device.dart' as rust_device;
import 'package:trascribe/src/rust/session.dart' as rust_session;
import 'package:trascribe/src/rust/stt/file.dart' as rust_stt_file;

class _FakeBridge implements RustBridge {
  AppSettings savedSettings = AppSettings.defaults();
  final List<(String, String)> downloadModelCalls = [];

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
  Future<AppSettings> loadSettings() async => savedSettings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    savedSettings = settings;
  }

  @override
  Future<void> downloadModel(String modelsDir, String modelId) {
    downloadModelCalls.add((modelsDir, modelId));
    return Future.value();
  }

  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() async => const [];

  @override
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() async => const [];

  @override
  Future<String> detectFrontmostWindowTitle() async => '';

  @override
  Stream<double> downloadProgress() =>
      Stream.fromIterable([0.0, 0.5, 1.0]);

  @override
  Future<List<rust_stt_file.TranscribeFileResult>> batchTranscribeFiles({
    required String modelPath,
    required List<String> files,
    String? language,
  }) async => [];
}

void main() {
  testWidgets('wizard walks through all 5 steps and calls onFinished', (WidgetTester tester) async {
    var finished = false;
    final bridge = _FakeBridge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: MaterialApp(home: SetupWizardScreen(onFinished: () => finished = true)),
      ),
    );

    expect(find.text('1. Deteksi Spesifikasi'), findsOneWidget);
    expect(find.text('Selesai'), findsNothing);

    for (final expectedTitle in [
      '2. Pilih Model',
      '3. Setup Audio',
      '4. Unduh Model',
      '5. Tone Test',
    ]) {
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text(expectedTitle), findsOneWidget);
    }

    expect(finished, isFalse);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('back button disabled on first step, enabled after', (WidgetTester tester) async {
    final bridge = _FakeBridge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: MaterialApp(home: SetupWizardScreen(onFinished: () {})),
      ),
    );

    final backButton = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Kembali'));
    expect(backButton.onPressed, isNull);

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    final backButtonAfter = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Kembali'));
    expect(backButtonAfter.onPressed, isNotNull);
  });

  testWidgets('selecting a model persists it through the settings provider', (
    WidgetTester tester,
  ) async {
    final bridge = _FakeBridge();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: MaterialApp(
          home: SetupWizardScreen(onFinished: () {}),
        ),
      ),
    );

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('small (~500 MB)'));
    await tester.pumpAndSettle();

    expect(bridge.savedSettings.defaultModel, 'small');
  });

  testWidgets('downloading a model calls bridge and records a privacy report event', (
    WidgetTester tester,
  ) async {
    final bridge = _FakeBridge();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: const MaterialApp(
          home: SetupWizardScreen(onFinished: _noop),
        ),
      ),
    );

    // Step 1 → Step 2
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Step 2: select 'base' model (not bundled) so download button appears
    await tester.tap(find.text('base (~150 MB)'));
    await tester.pumpAndSettle();

    // Step 2 → Step 3
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Step 3 → Step 4
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Unduh model'), findsOneWidget);

    await tester.tap(find.text('Unduh model'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(bridge.downloadModelCalls.length, 1);
    expect(bridge.downloadModelCalls.single.$2, 'base');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SetupWizardScreen)),
      listen: false,
    );
    final report = container.read(privacyReportProvider);

    expect(report.networkCallCount, 1);
    expect(report.events.single, contains('Download model "base"'));

    // After download completes, onRecordDownload advances to step 5
    await tester.pumpAndSettle();
    expect(find.text('Selesai'), findsOneWidget);
  });

  testWidgets('navigating past download step without clicking does not trigger bridge or privacy report', (
    WidgetTester tester,
  ) async {
    final bridge = _FakeBridge();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: const MaterialApp(
          home: SetupWizardScreen(onFinished: _noop),
        ),
      ),
    );

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
    }

    expect(bridge.downloadModelCalls, isEmpty);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SetupWizardScreen)),
      listen: false,
    );
    final report = container.read(privacyReportProvider);

    expect(report.networkCallCount, 0);
  });
}

void _noop() {}
