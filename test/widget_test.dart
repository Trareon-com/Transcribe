import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/main.dart';
import 'package:trascribe/services/bridge_service.dart';
import 'package:trascribe/state/models.dart';
import 'package:trascribe/state/settings_model.dart';

/// Timer-free test double — the real [RustBridgeMock] runs a periodic
/// Timer that leaks across widget-test teardown; widget tests only need
/// deterministic start/stop behavior, not simulated live segments.
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
  Future<AppSettings> loadSettings() async => AppSettings.defaults();

  @override
  Future<void> saveSettings(AppSettings settings) async {}
}

void main() {
  Widget buildApp() {
    return ProviderScope(
      overrides: [rustBridgeProvider.overrideWithValue(_NoopBridge())],
      child: const TrascribeApp(),
    );
  }

  testWidgets('main screen renders mode selector and start button', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.text('Mulai'), findsOneWidget);
    expect(find.text('Webinar'), findsOneWidget);
    expect(find.text('Rapat Online'), findsOneWidget);
    expect(find.text('Rapat Offline'), findsOneWidget);
  });

  testWidgets('starting a session switches button to Stop', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    await tester.tap(find.text('Mulai'));
    await tester.pump();

    expect(find.text('Stop'), findsOneWidget);
  });

  testWidgets('settings icon navigates to settings screen', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();

    expect(find.text('Pengaturan'), findsWidgets);
    expect(find.text('Tema'), findsOneWidget);
  });
}
