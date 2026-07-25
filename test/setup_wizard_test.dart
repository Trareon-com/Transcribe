import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/screens/setup_wizard_screen.dart';
import 'package:trascribe/services/bridge_service.dart';
import 'package:trascribe/state/models.dart';
import 'package:trascribe/state/privacy_report_model.dart';
import 'package:trascribe/state/settings_model.dart';
import 'package:trascribe/src/rust/session.dart' as rust_session;

class _FakeBridge implements RustBridge {
  AppSettings savedSettings = AppSettings.defaults();

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
}

void main() {
  testWidgets('wizard walks through all 5 steps and calls onFinished', (WidgetTester tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(home: SetupWizardScreen(onFinished: () => finished = true)),
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
    await tester.pumpWidget(MaterialApp(home: SetupWizardScreen(onFinished: () {})));

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

  testWidgets('downloading a model records a privacy report event', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SetupWizardScreen(onFinished: _noop),
        ),
      ),
    );

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Unduh model'), findsOneWidget);

    await tester.tap(find.text('Unduh model'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SetupWizardScreen)),
      listen: false,
    );
    final report = container.read(privacyReportProvider);

    expect(report.networkCallCount, 1);
    expect(report.events.single, contains('Download model "tiny"'));
    expect(find.text('Sudah dicatat'), findsOneWidget);
  });
}

void _noop() {}
