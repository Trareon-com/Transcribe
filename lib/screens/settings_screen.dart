import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/models.dart';
import '../state/settings_model.dart';
import 'privacy_report_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Tema'),
            subtitle: Text(_themeLabel(settings.theme)),
            trailing: DropdownButton<AppThemeMode>(
              value: settings.theme,
              items: AppThemeMode.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(_themeLabel(m))))
                  .toList(),
              onChanged: (theme) {
                if (theme != null) notifier.setTheme(theme);
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Mode default'),
            subtitle: Text(settings.defaultMode.label),
            trailing: DropdownButton<SessionMode>(
              value: settings.defaultMode,
              items: SessionMode.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                  .toList(),
              onChanged: (mode) {
                if (mode != null) notifier.setDefaultMode(mode);
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Model default'),
            subtitle: Text(settings.defaultModel),
          ),
          ListTile(
            title: const Text('Lokasi library'),
            subtitle: Text(settings.libraryPath),
          ),
          SwitchListTile(
            title: const Text('VAD (deteksi suara)'),
            value: settings.vadEnabled,
            onChanged: null,
          ),
          SwitchListTile(
            title: const Text('Echo-dedupe'),
            value: settings.echoDedupeEnabled,
            onChanged: null,
          ),
          const Divider(),
          ListTile(
            title: const Text('Privacy Report'),
            subtitle: const Text('Lihat aktivitas jaringan sejak app dibuka'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyReportScreen()),
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(AppThemeMode theme) => switch (theme) {
        AppThemeMode.light => 'Terang',
        AppThemeMode.dark => 'Gelap',
        AppThemeMode.system => 'Ikuti Sistem',
      };
}
