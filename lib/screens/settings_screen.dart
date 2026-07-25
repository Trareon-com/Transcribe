import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/models.dart';
import '../state/settings_model.dart';
import 'privacy_report_screen.dart';
import 'usage_dashboard_screen.dart';

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
          Semantics(
            label: 'Pengaturan tema',
            child: ListTile(
              title: const Text('Tema'),
              subtitle: Text(_themeLabel(settings.theme)),
              trailing: Semantics(
                label: 'Pilih tema',
                button: true,
                child: DropdownButton<AppThemeMode>(
                  value: settings.theme,
                  items: AppThemeMode.values
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Semantics(
                              label: _themeLabel(m),
                              child: Text(_themeLabel(m)),
                            ),
                          ))
                      .toList(),
                  onChanged: (theme) {
                    if (theme != null) notifier.setTheme(theme);
                  },
                ),
              ),
            ),
          ),
          const Divider(),
          Semantics(
            label: 'Pengaturan model default',
            child: ListTile(
              title: const Text('Model default'),
              subtitle: Text(settings.defaultModel),
              trailing: Semantics(
                label: 'Pilih model default, saat ini ${settings.defaultModel}',
                button: true,
                child: DropdownButton<String>(
                  value: settings.defaultModel,
                  items: const [
                    DropdownMenuItem(value: 'tiny', child: Text('tiny')),
                    DropdownMenuItem(value: 'base', child: Text('base')),
                    DropdownMenuItem(value: 'small', child: Text('small')),
                    DropdownMenuItem(value: 'medium', child: Text('medium')),
                    DropdownMenuItem(value: 'large-v3-turbo', child: Text('large-v3-turbo')),
                  ],
                  onChanged: (model) {
                    if (model != null) notifier.setDefaultModel(model);
                  },
                ),
              ),
            ),
          ),
          const Divider(),
          Semantics(
            label: 'Pengaturan mode default',
            child: ListTile(
              title: const Text('Mode default'),
              subtitle: Text(settings.defaultMode.label),
              trailing: Semantics(
                label: 'Pilih mode default, saat ini ${settings.defaultMode.label}',
                button: true,
                child: DropdownButton<SessionMode>(
                  value: settings.defaultMode,
                  items: SessionMode.values
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Semantics(
                              label: m.label,
                              child: Text(m.label),
                            ),
                          ))
                      .toList(),
                  onChanged: (mode) {
                    if (mode != null) notifier.setDefaultMode(mode);
                  },
                ),
              ),
            ),
          ),
          const Divider(),
          Semantics(
            label: 'Pengaturan lokasi library',
            child: ListTile(
              title: const Text('Lokasi library'),
              subtitle: Text(settings.libraryPath),
              trailing: SizedBox(
                width: 240,
                child: Semantics(
                  textField: true,
                  label: 'Path lokasi library, saat ini ${settings.libraryPath}',
                  child: TextFormField(
                    initialValue: settings.libraryPath,
                    decoration: const InputDecoration(
                      hintText: '/Users/user/Documents/Trascribe',
                      isDense: true,
                    ),
                    onFieldSubmitted: notifier.setLibraryPath,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            label: 'VAD deteksi suara, ${settings.vadEnabled ? 'aktif' : 'nonaktif'}',
            child: SwitchListTile(
              title: const Text('VAD (deteksi suara)'),
              value: settings.vadEnabled,
              onChanged: (value) => notifier.setVadEnabled(value),
            ),
          ),
          Semantics(
            label: 'Echo dedupe, ${settings.echoDedupeEnabled ? 'aktif' : 'nonaktif'}',
            child: SwitchListTile(
              title: const Text('Echo-dedupe'),
              value: settings.echoDedupeEnabled,
              onChanged: (value) => notifier.setEchoDedupeEnabled(value),
            ),
          ),
          SwitchListTile(
            title: const Text('Auto-stop saat diam'),
            subtitle: Text(
              settings.autoStopMinutes != null
                  ? 'Berhenti otomatis setelah ${settings.autoStopMinutes} menit tanpa deteksi suara'
                  : 'Nonaktif',
            ),
            value: settings.autoStopMinutes != null,
            onChanged: (enabled) {
              notifier.setAutoStopMinutes(enabled ? 5 : null);
            },
          ),
          if (settings.autoStopMinutes != null)
            ListTile(
              title: const Text('Batas waktu diam'),
              subtitle: Text('${settings.autoStopMinutes} menit'),
              trailing: SizedBox(
                width: 120,
                child: Slider(
                  min: 1,
                  max: 30,
                  divisions: 29,
                  value: settings.autoStopMinutes!.toDouble().clamp(1, 30),
                  label: '${settings.autoStopMinutes} menit',
                  onChanged: (v) => notifier.setAutoStopMinutes(v.round()),
                ),
              ),
            ),
          Semantics(
            label: 'Pengaturan bahasa',
            child: ListTile(
              title: const Text('Bahasa'),
              subtitle: Text(settings.language ?? 'Auto-detect'),
              trailing: Semantics(
                label: 'Pilih bahasa, saat ini ${settings.language ?? 'Auto-detect'}',
                button: true,
                child: DropdownButton<String?>(
                  value: settings.language,
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('Auto-detect')),
                    DropdownMenuItem<String?>(value: 'id', child: Text('Bahasa Indonesia')),
                    DropdownMenuItem<String?>(value: 'en', child: Text('English')),
                  ],
                  onChanged: (language) {
                    notifier.setLanguage(language);
                  },
                ),
              ),
            ),
          ),
          const Divider(),
          Semantics(
            label: 'Privacy Report - Lihat aktivitas jaringan sejak app dibuka',
            button: true,
            child: ListTile(
              title: const Text('Privacy Report'),
              subtitle: const Text('Lihat aktivitas jaringan sejak app dibuka'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyReportScreen()),
              ),
            ),
          ),
          Semantics(
            label: 'Statistik Penggunaan - Total sesi, jam ditranskrip, dan mode yang paling sering dipakai',
            button: true,
            child: ListTile(
              title: const Text('Statistik Penggunaan'),
              subtitle: const Text('Total sesi, jam ditranskrip, dan mode yang paling sering dipakai'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UsageDashboardScreen()),
              ),
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
