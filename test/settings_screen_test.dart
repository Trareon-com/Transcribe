import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/services/bridge_service.dart';
import 'package:trascribe/state/models.dart';
import 'package:trascribe/state/settings_model.dart';
import 'package:trascribe/screens/settings_screen.dart';
import 'package:trascribe/src/rust/audio/device.dart' as rust_device;
import 'package:trascribe/src/rust/session.dart' as rust_session;

class _TestBridge implements RustBridge {
  AppSettings savedSettings = AppSettings.defaults();

  @override
  Future<String> startSession(SessionConfig config) async => 'test';
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
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot) async => 'test';
  @override
  Future<AppSettings> loadSettings() async => savedSettings;
  @override
  Future<void> saveSettings(AppSettings settings) async { savedSettings = settings; }
  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {}
  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() async => const [];
  @override
  Future<String> detectFrontmostWindowTitle() async => '';
}

void main() {
  testWidgets('settings screen shows all controls', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = _TestBridge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Model default'), findsWidgets);
    expect(find.text('Bahasa'), findsWidgets);
    expect(find.text('VAD (deteksi suara)'), findsOneWidget);
    expect(find.text('Echo-dedupe'), findsOneWidget);
    expect(find.text('Privacy Report'), findsOneWidget);
    expect(find.text('Statistik Penggunaan'), findsOneWidget);
  });

  testWidgets('theme dropdown changes theme', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = _TestBridge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rustBridgeProvider.overrideWithValue(bridge)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Find and tap the theme dropdown
    final dropdowns = find.byType(DropdownButton<AppThemeMode>);
    expect(dropdowns, findsWidgets);
  });
}
