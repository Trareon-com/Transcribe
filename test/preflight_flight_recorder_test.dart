// Copyright 2026 YSF Studio. Licensed under Privacy-Preserving Software License v1.0.
// SPDX-License-Identifier: PPSL
//
// Tests for the pre-flight check service and flight recorder.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trascribe/services/flight_recorder.dart';
import 'package:trascribe/services/preflight_check.dart';
import 'package:trascribe/services/bridge_service.dart';
import 'package:trascribe/state/models.dart';
import 'package:trascribe/src/rust/audio/device.dart' as rust_device;
import 'package:trascribe/src/rust/session.dart' as rust_session;

// ── Test double ──────────────────────────────────────────────────────

class _EmptyBridge implements RustBridge {
  @override
  Future<List<rust_device.AudioDeviceInfo>> listAudioDevices() async => [];

  @override
  Future<List<rust_device.AudioDeviceInfo>> listOutputAudioDevices() async => [];

  @override
  Future<String> startSession(SessionConfig config) async => 's1';

  @override
  Future<void> stopSession(String id) async {}

  @override
  Future<void> toggleMic(String sessionId, bool enabled) async {}

  @override
  Future<void> toggleSpeaker(String sessionId, bool enabled) async {}

  @override
  Stream<TranscriptSegment> transcriptStream(String sessionId) async* {}

  @override
  Stream<VuLevel> vuMeterStream(String sessionId) async* {}

  @override
  Future<List<rust_session.SessionRecoverySnapshot>> listRecoverableSessions() async => [];

  @override
  Future<String> recoverSession(rust_session.SessionRecoverySnapshot snapshot) async => '';

  @override
  Future<String> detectFrontmostWindowTitle() async => '';

  @override
  Future<void> downloadModel(String modelsDir, String modelId) async {}

  @override
  Future<AppSettings> loadSettings() async => AppSettings.defaults();

  @override
  Future<void> saveSettings(AppSettings settings) async {}
}

// ── Tests ────────────────────────────────────────────────────────────

void main() {
  final bridge = _EmptyBridge();
  final config = SessionConfig(
    micEnabled: true,
    speakerEnabled: true,
    mode: SessionMode.webinar,
    modelPath: '~/nonexistent-model.bin',
  );

  group('PreflightCheck', () {
    test('blocking when mic enabled but no input devices', () async {
      final report = await runPreflightChecks(
        bridge: bridge,
        config: config,
        modelPath: '/nonexistent/model.bin',
      );
      expect(report.blocking.any((i) => i.id == 'no_mic'), isTrue);
      expect(report.isReady, isFalse);
    });

    test('blocking when model file missing', () async {
      final report = await runPreflightChecks(
        bridge: bridge,
        config: config,
        modelPath: '/definitely/not/a/model.bin',
      );
      expect(report.blocking.any((i) => i.id == 'model_missing'), isTrue);
      expect(report.isReady, isFalse);
    });
  });

  group('FlightRecorder', () {
    test('logs lifecycle events', () async {
      final recorder = FlightRecorder.instance;
      recorder.useFile(File(
          '${Directory.systemTemp.path}/test_flight_recorder_${DateTime.now().millisecondsSinceEpoch}.jsonl'));
      await recorder.clearLog();
      await recorder.logLifecycle(sessionId: 's1', from: 'idle', to: 'recording');
      await recorder.logLifecycle(sessionId: 's1', from: 'recording', to: 'paused');
      final log = await recorder.readLog();
      expect(log, contains('lifecycle'));
      expect(log, contains('"from":"idle"'));
      expect(log, contains('"to":"paused"'));
    });

    test('never records transcript content', () async {
      final recorder = FlightRecorder.instance;
      await recorder.logSystem(
        event: 'test',
        details: {'batch': 3, 'queue': 1},
      );
      final log = await recorder.readLog();
      expect(log, contains('"type":"system"'));
      // Schema sanity: no 'text' or 'content' keys anywhere.
      expect(log, isNot(contains('"text"')));
      expect(log, isNot(contains('"content"')));
    });
  });
}
