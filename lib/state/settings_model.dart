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
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(rustBridgeProvider));
});
