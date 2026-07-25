/// Dart-side mirrors of the Rust API types (rust_core/src/{audio,export,settings}.rs).
/// Once FRB codegen is wired (Fase 5) these become generated bindings;
/// keeping them hand-written now lets UI development proceed in parallel.
library;

enum SessionMode { webinar, online, offline }

String modelPathForId(String modelId) {
  return switch (modelId) {
    'tiny' => 'models/ggml-tiny.bin',
    'base' => 'models/ggml-base.bin',
    'small' => 'models/ggml-small.bin',
    'medium' => 'models/ggml-medium.bin',
    'large-v3-turbo' => 'models/ggml-large-v3-turbo.bin',
    _ => 'models/ggml-$modelId.bin',
  };
}

extension SessionModeDefaults on SessionMode {
  (bool mic, bool speaker) get defaultToggles => switch (this) {
        SessionMode.webinar => (false, true),
        SessionMode.online => (true, true),
        SessionMode.offline => (true, false),
      };

  bool get echoDedupeEnabled => this == SessionMode.online;

  String get label => switch (this) {
        SessionMode.webinar => 'Webinar',
        SessionMode.online => 'Rapat Online',
        SessionMode.offline => 'Rapat Offline',
      };
}

class SessionConfig {
  final bool micEnabled;
  final bool speakerEnabled;
  final SessionMode mode;
  final String modelPath;
  final bool vadEnabled;

  const SessionConfig({
    required this.micEnabled,
    required this.speakerEnabled,
    required this.mode,
    required this.modelPath,
    this.vadEnabled = true,
  });

  factory SessionConfig.forMode(SessionMode mode, String modelPath) {
    final (mic, speaker) = mode.defaultToggles;
    return SessionConfig(
      micEnabled: mic,
      speakerEnabled: speaker,
      mode: mode,
      modelPath: modelPath,
    );
  }

  SessionConfig copyWith({bool? micEnabled, bool? speakerEnabled, SessionMode? mode}) {
    return SessionConfig(
      micEnabled: micEnabled ?? this.micEnabled,
      speakerEnabled: speakerEnabled ?? this.speakerEnabled,
      mode: mode ?? this.mode,
      modelPath: modelPath,
      vadEnabled: vadEnabled,
    );
  }
}

class TranscriptSegment {
  final String source;
  final String speaker;
  final String text;
  final double timestamp;
  final double duration;
  final String language;
  final double confidence;
  final bool isPartial;

  const TranscriptSegment({
    required this.source,
    required this.speaker,
    required this.text,
    required this.timestamp,
    required this.duration,
    required this.language,
    required this.confidence,
    required this.isPartial,
  });

  TranscriptSegment copyWith({String? text}) {
    return TranscriptSegment(
      source: source,
      speaker: speaker,
      text: text ?? this.text,
      timestamp: timestamp,
      duration: duration,
      language: language,
      confidence: confidence,
      isPartial: isPartial,
    );
  }
}

class VuLevel {
  final double micLevel;
  final double speakerLevel;

  const VuLevel({required this.micLevel, required this.speakerLevel});
}

enum AppThemeMode { light, dark, system }

class AppSettings {
  final AppThemeMode theme;
  final String defaultModel;
  final SessionMode defaultMode;
  final String libraryPath;
  final bool vadEnabled;
  final bool echoDedupeEnabled;
  final String? language;
  final int? autoStopMinutes;

  const AppSettings({
    required this.theme,
    required this.defaultModel,
    required this.defaultMode,
    required this.libraryPath,
    required this.vadEnabled,
    required this.echoDedupeEnabled,
    this.language,
    this.autoStopMinutes,
  });

  factory AppSettings.defaults() => const AppSettings(
        theme: AppThemeMode.light,
        defaultModel: 'tiny',
        defaultMode: SessionMode.online,
        libraryPath: '~/Documents/Trascribe',
        vadEnabled: true,
        echoDedupeEnabled: true,
      );

  AppSettings copyWith({
    AppThemeMode? theme,
    SessionMode? defaultMode,
    int? autoStopMinutes,
    bool clearAutoStop = false,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      defaultModel: defaultModel,
      defaultMode: defaultMode ?? this.defaultMode,
      libraryPath: libraryPath,
      vadEnabled: vadEnabled,
      echoDedupeEnabled: echoDedupeEnabled,
      language: language,
      autoStopMinutes: clearAutoStop ? null : (autoStopMinutes ?? this.autoStopMinutes),
    );
  }
}
