import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/bridge_service.dart';
import '../services/dart_prefs.dart';
import 'models.dart';

final rustBridgeProvider = Provider<RustBridge>((ref) => RustEngineBridge());

class SettingsNotifier extends StateNotifier<AppSettings> {
  final RustBridge _bridge;
  // Set to true as soon as either (a) the disk load completes or (b) a user
  // action fires — whichever comes first. Prevents the disk load from
  // overwriting an in-flight user change.
  bool _userActed = false;

  SettingsNotifier(this._bridge) : super(AppSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    // Load Dart-only prefs (e.g. defaultExportFormat) alongside Rust settings.
    await DartPrefs.instance.load();
    final loaded = await _bridge.loadSettings();
    if (_userActed) return;
    _userActed = true;
    final withDartPrefs = AppSettings(
      theme: loaded.theme,
      defaultModel: loaded.defaultModel,
      defaultMode: loaded.defaultMode,
      libraryPath: loaded.libraryPath,
      vadEnabled: loaded.vadEnabled,
      language: loaded.language,
      autoStopMinutes: loaded.autoStopMinutes,
      defaultExportFormat:
          DartPrefs.instance.getString('defaultExportFormat') ?? 'markdown',
      micDeviceId: DartPrefs.instance.getString('micDeviceId'),
      speakerDeviceId: DartPrefs.instance.getString('speakerDeviceId'),
    );
    final sanitized = _sanitizeDefaultModel(withDartPrefs);
    state = sanitized;
    if (sanitized.defaultModel != loaded.defaultModel) {
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
      language: settings.language,
      autoStopMinutes: settings.autoStopMinutes,
      defaultExportFormat: settings.defaultExportFormat,
      micDeviceId: settings.micDeviceId,
      speakerDeviceId: settings.speakerDeviceId,
    );
  }

  Future<void> setTheme(AppThemeMode theme) async {
    _userActed = true;
    state = state.copyWith(theme: theme);
    await _bridge.saveSettings(state);
  }

  /// Toggle between light ↔ dark. If system, treat as light first.
  Future<void> toggleTheme() async {
    final next = state.theme == AppThemeMode.dark ? AppThemeMode.light : AppThemeMode.dark;
    await setTheme(next);
  }

  Future<void> setDefaultMode(SessionMode mode) async {
    _userActed = true;
    state = state.copyWith(defaultMode: mode);
    await _bridge.saveSettings(state);
  }

  Future<void> setLibraryPath(String path) async {
    _userActed = true;
    state = AppSettings(
      theme: state.theme,
      defaultModel: state.defaultModel,
      defaultMode: state.defaultMode,
      libraryPath: path,
      vadEnabled: state.vadEnabled,
      language: state.language,
      autoStopMinutes: state.autoStopMinutes,
      defaultExportFormat: state.defaultExportFormat,
      micDeviceId: state.micDeviceId,
      speakerDeviceId: state.speakerDeviceId,
    );
    await _bridge.saveSettings(state);
  }

  Future<void> setVadEnabled(bool enabled) async {
    _userActed = true;
    state = AppSettings(
      theme: state.theme,
      defaultModel: state.defaultModel,
      defaultMode: state.defaultMode,
      libraryPath: state.libraryPath,
      vadEnabled: enabled,
      language: state.language,
      autoStopMinutes: state.autoStopMinutes,
      defaultExportFormat: state.defaultExportFormat,
      micDeviceId: state.micDeviceId,
      speakerDeviceId: state.speakerDeviceId,
    );
    await _bridge.saveSettings(state);
  }

  Future<void> setLanguage(String? language) async {
    _userActed = true;
    state = AppSettings(
      theme: state.theme,
      defaultModel: state.defaultModel,
      defaultMode: state.defaultMode,
      libraryPath: state.libraryPath,
      vadEnabled: state.vadEnabled,
      language: language,
      autoStopMinutes: state.autoStopMinutes,
      defaultExportFormat: state.defaultExportFormat,
      micDeviceId: state.micDeviceId,
      speakerDeviceId: state.speakerDeviceId,
    );
    await _bridge.saveSettings(state);
  }

  Future<void> setDefaultModel(String modelId) async {
    _userActed = true;
    state = AppSettings(
      theme: state.theme,
      defaultModel: modelId,
      defaultMode: state.defaultMode,
      libraryPath: state.libraryPath,
      vadEnabled: state.vadEnabled,
      language: state.language,
      autoStopMinutes: state.autoStopMinutes,
      defaultExportFormat: state.defaultExportFormat,
      micDeviceId: state.micDeviceId,
      speakerDeviceId: state.speakerDeviceId,
    );
    await _bridge.saveSettings(state);
  }

  Future<void> setAutoStopMinutes(int? minutes) async {
    _userActed = true;
    state = AppSettings(
      theme: state.theme,
      defaultModel: state.defaultModel,
      defaultMode: state.defaultMode,
      libraryPath: state.libraryPath,
      vadEnabled: state.vadEnabled,
      language: state.language,
      autoStopMinutes: minutes,
      defaultExportFormat: state.defaultExportFormat,
      micDeviceId: state.micDeviceId,
      speakerDeviceId: state.speakerDeviceId,
    );
    await _bridge.saveSettings(state);
  }

  Future<void> setDefaultExportFormat(String format) async {
    _userActed = true;
    state = AppSettings(
      theme: state.theme,
      defaultModel: state.defaultModel,
      defaultMode: state.defaultMode,
      libraryPath: state.libraryPath,
      vadEnabled: state.vadEnabled,
      language: state.language,
      autoStopMinutes: state.autoStopMinutes,
      defaultExportFormat: format,
      micDeviceId: state.micDeviceId,
      speakerDeviceId: state.speakerDeviceId,
    );
    // Persist to DartPrefs so the value survives app restarts.
    DartPrefs.instance.setString('defaultExportFormat', format);
    await DartPrefs.instance.save();
    await _bridge.saveSettings(state);
  }

  Future<void> setMicDeviceName(String? name) async {
    _userActed = true;
    state = state.copyWith(micDeviceId: name);
    if (name != null) {
      DartPrefs.instance.setString('micDeviceId', name);
    }
    await DartPrefs.instance.save();
    await _bridge.saveSettings(state);
  }

  Future<void> setSpeakerDeviceName(String? name) async {
    _userActed = true;
    state = state.copyWith(speakerDeviceId: name);
    if (name != null) {
      DartPrefs.instance.setString('speakerDeviceId', name);
    }
    await DartPrefs.instance.save();
    await _bridge.saveSettings(state);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  // ref.read is correct here — RustBridge is a stable singleton, no need to
  // watch it for rebuilds.  Using ref.watch would cause unnecessary rebuilds
  // if the provider were ever invalidated.
  return SettingsNotifier(ref.read(rustBridgeProvider));
});
