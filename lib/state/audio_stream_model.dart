import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'session_model.dart';
import 'settings_model.dart';

/// Streams VU levels for the currently active session; auto-disposes its
/// subscription when the widget tree stops watching it.
final vuLevelProvider = StreamProvider<VuLevel>((ref) {
  final bridge = ref.watch(rustBridgeProvider);
  final sessionId = ref.watch(sessionProvider).sessionId;
  if (sessionId == null) {
    return const Stream<VuLevel>.empty();
  }
  return bridge.vuMeterStream(sessionId);
});
