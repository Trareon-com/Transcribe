import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks network activity since app launch for the Privacy Report screen.
/// The app makes zero network calls during transcription by design (see
/// SECURITY.md); the only legitimate increments come from an explicit,
/// user-initiated model download. Anything else touching this counter
/// would be a privacy regression worth flagging loudly.
class PrivacyReportState {
  final int networkCallCount;
  final DateTime launchedAt;
  final List<String> events;

  const PrivacyReportState({
    required this.networkCallCount,
    required this.launchedAt,
    this.events = const [],
  });

  PrivacyReportState copyWith({int? networkCallCount, List<String>? events}) {
    return PrivacyReportState(
      networkCallCount: networkCallCount ?? this.networkCallCount,
      launchedAt: launchedAt,
      events: events ?? this.events,
    );
  }
}

class PrivacyReportNotifier extends StateNotifier<PrivacyReportState> {
  PrivacyReportNotifier() : super(PrivacyReportState(networkCallCount: 0, launchedAt: DateTime.now()));

  /// Called only from the explicit, user-initiated model download flow —
  /// never from the transcription pipeline.
  void recordModelDownload(String modelId) {
    state = state.copyWith(
      networkCallCount: state.networkCallCount + 1,
      events: [...state.events, 'Download model "$modelId" — ${DateTime.now()}'],
    );
  }
}

final privacyReportProvider = StateNotifierProvider<PrivacyReportNotifier, PrivacyReportState>((ref) {
  return PrivacyReportNotifier();
});
