/// Dart-side mirrors of the Rust API types (rust_core/src/{audio,export,settings}.rs).
/// Once FRB codegen is wired (Fase 5) these become generated bindings;
/// keeping them hand-written now lets UI development proceed in parallel.
library;

import 'dart:io';

enum SessionMode { webinar, online, offline }

/// Resolves a leading `~` in [path] to the user's home directory.
String resolveTilde(String path) {
  if (path.startsWith('~/')) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home${path.substring(1)}';
  }
  return path;
}

String _modelFileName(String modelId) => switch (modelId) {
  'tiny' => 'ggml-tiny.bin',
  'base' => 'ggml-base.bin',
  'small' => 'ggml-small.bin',
  'medium' => 'ggml-medium.bin',
  'large-v3-turbo' => 'ggml-large-v3-turbo.bin',
  _ => 'ggml-$modelId.bin',
};

/// Resolves a model id to an absolute file path. The bare relative path
/// `models/ggml-*.bin` only resolves by coincidence when a process happens
/// to have the repo root as its CWD (e.g. a shell-launched `cargo run`) — a
/// normally-launched (or macOS-sandboxed) app never does, so this checks,
/// in order: (1) the configured library path — where downloadModel() saves
/// non-bundled models, and matches Rust's own resolve_model_path(); (2) the
/// bundled-vs-dev-tree executable-relative search already used by
/// [rust_library_loader.dart] for the native library. macOS App Sandbox
/// blocks opening arbitrary paths outside the bundle/container, so relying
/// only on (2) works in dev but never in a sandboxed release build.
String modelPathForId(String modelId, {String? libraryPath}) {
  final fileName = _modelFileName(modelId);

  // Known macOS model cache location
  String? homeCachePath;
  final home = Platform.environment['HOME'];
  if (home != null) {
    homeCachePath = '$home/Library/Caches/TrareonTranscribe/models/$fileName';
  }
  // Known Windows model cache location
  String? localAppDataPath;
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null) {
    localAppDataPath = '$localAppData\\TrareonTranscribe\\models\\$fileName';
  }

  final candidates = [
    if (libraryPath != null && libraryPath.isNotEmpty)
      '${resolveTilde(libraryPath)}/$fileName',
    ?homeCachePath,
    ?localAppDataPath,
    _bundledResourcesPath(fileName),
    ..._devTreePaths(fileName),
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) return candidate;
  }
  // Last-resort fallback
  return 'models/$fileName';
}

/// Whether [modelId]'s file actually exists somewhere modelPathForId()
/// would find it. Selecting an unavailable model as the default (there is
/// no in-UI download affordance outside the setup wizard) previously
/// crashed session start with an unhandled "model file not found"
/// exception — callers should check this before committing the choice.
bool isModelAvailable(String modelId, {String? libraryPath}) {
  final fileName = _modelFileName(modelId);
  final home = Platform.environment['HOME'];
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final candidates = [
    if (libraryPath != null && libraryPath.isNotEmpty)
      '${libraryPath.startsWith('~/') && home != null ? '$home${libraryPath.substring(1)}' : libraryPath}/$fileName',
    if (home != null) '$home/Library/Caches/TrareonTranscribe/models/$fileName',
    if (localAppData != null) '$localAppData\\TrareonTranscribe\\models\\$fileName',
    _bundledResourcesPath(fileName),
    ..._devTreePaths(fileName),
  ];
  return candidates.any((c) => File(c).existsSync());
}

String _bundledResourcesPath(String fileName) {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  if (Platform.isMacOS) {
    return '$exeDir/../Resources/models/$fileName';
  }
  return '$exeDir/models/$fileName';
}

List<String> _devTreePaths(String fileName) {
  // Walk up from the executable looking for a `models/` directory —
  // works for `flutter run` (exe under build/{platform}/.../Debug)
  // without hardcoding a repo-root assumption.
  var dir = File(Platform.resolvedExecutable).parent;
  final paths = <String>[];
  for (var i = 0; i < 14; i++) {
    paths.add('${dir.path}/models/$fileName');
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return paths;
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
  final String? micDeviceId;
  final String? speakerDeviceId;

  const SessionConfig({
    required this.micEnabled,
    required this.speakerEnabled,
    required this.mode,
    required this.modelPath,
    this.vadEnabled = true,
    this.micDeviceId,
    this.speakerDeviceId,
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

  SessionConfig copyWith({
    bool? micEnabled,
    bool? speakerEnabled,
    SessionMode? mode,
    bool? vadEnabled,
    String? micDeviceId,
    String? speakerDeviceId,
  }) {
    return SessionConfig(
      micEnabled: micEnabled ?? this.micEnabled,
      speakerEnabled: speakerEnabled ?? this.speakerEnabled,
      mode: mode ?? this.mode,
      modelPath: modelPath,
      vadEnabled: vadEnabled ?? this.vadEnabled,
      micDeviceId: micDeviceId ?? this.micDeviceId,
      speakerDeviceId: speakerDeviceId ?? this.speakerDeviceId,
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
  final String? language;
  final int? autoStopMinutes;

  const AppSettings({
    required this.theme,
    required this.defaultModel,
    required this.defaultMode,
    required this.libraryPath,
    required this.vadEnabled,
    this.language,
    this.autoStopMinutes,
  });

  factory AppSettings.defaults() => const AppSettings(
        theme: AppThemeMode.light,
        defaultModel: 'tiny',
        defaultMode: SessionMode.online,
        libraryPath: '~/Documents/Trascribe',
        vadEnabled: true,
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
      language: language,
      autoStopMinutes: clearAutoStop ? null : (autoStopMinutes ?? this.autoStopMinutes),
    );
  }
}
