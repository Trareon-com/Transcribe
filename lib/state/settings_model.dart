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
    state = await _bridge.loadSettings();
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
    );
    await _bridge.saveSettings(state);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(rustBridgeProvider));
});
