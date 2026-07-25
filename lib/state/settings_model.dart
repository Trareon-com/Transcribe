import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import 'models.dart';

final rustBridgeProvider = Provider<RustBridge>((ref) => RustEngineBridge());

class SettingsNotifier extends StateNotifier<AppSettings> {
  final RustBridge _bridge;

  SettingsNotifier(this._bridge) : super(AppSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    final loaded = await _bridge.loadSettings();
    if (state != AppSettings.defaults()) {
      return;
    }
    final sanitized = _sanitizeDefaultModel(loaded);
    state = sanitized;
    if (sanitized != loaded) {
      await _bridge.saveSettings(sanitized);
    }
  }

  AppSettings _sanitizeDefaultModel(AppSettings settings) {
    if (isModelAvailable(settings.defaultModel, libraryPath: settings.libraryPath)) {
      return settings;
    }
    const fallback = 'tiny';
    if (settings.defaultModel == fallback) return settings;
    return AppSettings(
      theme: settings.theme,
      defaultModel: fallback,
      defaultMode: settings.defaultMode,
      libraryPath: settings.libraryPath,
      vadEnabled: settings.vadEnabled,
      echoDedupeEnabled: settings.echoDedupeEnabled,
      language: settings.language,
      autoStopMinutes: settings.autoStopMinutes,
    );
  }

  Future<void> setTheme(AppThemeMode theme) async {
    state = state.copyWith(theme: theme);
    await _bridge.saveSettings(state);
  }

  Future<void> setDefaultMode(SessionMode mode) async {
    state = state.copyWith(defaultMode: mode);
    await _bridge.saveSettings(state);
  }

  Future<void> setLibraryPath(String path) async {
    state = AppSettings(
      theme: state.theme,
      defaultModel: state.defaultModel,
      defaultMode: state.defaultMode,
      libraryPath: path,
      vadEnabled: state.vadEnabled,
      echoDedupeEnabled: state.echoDedupeEnabled,
      language: state.language,
      autoStopMinutes: state.autoStopMinutes,
    );
    await _bridge.saveSettings(state);
  }

  Future<void> setVadEnabled(bool enabled) async {
    state = AppSettings(
      theme: state.theme,
      defaultModel: state.defaultModel,
      defaultMode: state.defaultMode,
      libraryPath: state.libraryPath,
      vadEnabled: enabled,
      echoDedupeEnabled: state.echoDedupeEnabled,
      language: state.language,
      autoStopMinutes: state.autoStopMinutes,
    );
    await _bridge.saveSettings(state);
  }

  Future<void> setEchoDedupeEnabled(bool enabled) async {
    state = AppSettings(
      theme: state.theme,
      defaultModel: state.defaultModel,
      defaultMode: state.defaultMode,
      libraryPath: state.libraryPath,
      vadEnabled: state.vadEnabled,
      echoDedupeEnabled: enabled,
      language: state.language,
      autoStopMinutes: state.autoStopMinutes,
    );
    await _bridge.saveSettings(state);
  }

  Future<void> setLanguage(String? language) async {
    state = AppSettings(
      theme: state.theme,
      defaultModel: state.defaultModel,
      defaultMode: state.defaultMode,
      libraryPath: state.libraryPath,
      vadEnabled: state.vadEnabled,
      echoDedupeEnabled: state.echoDedupeEnabled,
      language: language,
      autoStopMinutes: state.autoStopMinutes,
    );
    await _bridge.saveSettings(state);
  }

  Future<void> setDefaultModel(String modelId) async {
    state = AppSettings(
      theme: state.theme,
      defaultModel: modelId,
      defaultMode: state.defaultMode,
      libraryPath: state.libraryPath,
      vadEnabled: state.vadEnabled,
      echoDedupeEnabled: state.echoDedupeEnabled,
      language: state.language,
      autoStopMinutes: state.autoStopMinutes,
    );
    await _bridge.saveSettings(state);
  }

  Future<void> setAutoStopMinutes(int? minutes) async {
    state = AppSettings(
      theme: state.theme,
      defaultModel: state.defaultModel,
      defaultMode: state.defaultMode,
      libraryPath: state.libraryPath,
      vadEnabled: state.vadEnabled,
      echoDedupeEnabled: state.echoDedupeEnabled,
      language: state.language,
      autoStopMinutes: minutes,
    );
    await _bridge.saveSettings(state);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  // ref.read is correct here — RustBridge is a stable singleton, no need to
  // watch it for rebuilds.  Using ref.watch would cause unnecessary rebuilds
  // if the provider were ever invalidated.
  return SettingsNotifier(ref.read(rustBridgeProvider));
});
