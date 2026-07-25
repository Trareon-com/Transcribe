import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/update_checker.dart';
import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import 'privacy_report_screen.dart';
import 'usage_dashboard_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        foregroundColor: colors.text,
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: 'Tampilan',
            children: [
              _SettingsTile(
                icon: Icons.palette_outlined,
                label: 'Tema',
                trailing: _CompactDropdown<AppThemeMode>(
                  value: settings.theme,
                  items: AppThemeMode.values,
                  labelBuilder: _themeLabel,
                  onChanged: notifier.setTheme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Model & Mode',
            children: [
              _SettingsTile(
                icon: Icons.psychology_outlined,
                label: 'Model default',
                trailing: _CompactDropdown<String>(
                  value: settings.defaultModel,
                  items: const ['tiny', 'base', 'small', 'medium', 'large-v3-turbo'],
                  labelBuilder: (s) => s,
                  onChanged: (modelId) {
                    if (!isModelAvailable(modelId, libraryPath: settings.libraryPath)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Model "$modelId" belum diunduh. Unduh lewat Setup Wizard terlebih dahulu.',
                          ),
                        ),
                      );
                      return;
                    }
                    notifier.setDefaultModel(modelId);
                  },
                ),
              ),
              _SettingsTile(
                icon: Icons.meeting_room_outlined,
                label: 'Mode default',
                trailing: _CompactDropdown<SessionMode>(
                  value: settings.defaultMode,
                  items: SessionMode.values,
                  labelBuilder: (m) => m.label,
                  onChanged: notifier.setDefaultMode,
                ),
              ),
              _SettingsTile(
                icon: Icons.language_outlined,
                label: 'Bahasa',
                trailing: _CompactDropdown<String?>(
                  value: settings.language,
                  items: const [null, 'id', 'en'],
                  labelBuilder: (s) => s == null ? 'Auto-detect' : (s == 'id' ? 'Indonesia' : 'English'),
                  onChanged: notifier.setLanguage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Audio',
            children: [
              _SettingsSwitch(
                icon: Icons.graphic_eq_outlined,
                label: 'VAD (deteksi suara)',
                subtitle: 'Filter noise sekitar',
                value: settings.vadEnabled,
                onChanged: notifier.setVadEnabled,
              ),
              _SettingsSwitch(
                icon: Icons.spatial_audio_outlined,
                label: 'Echo-dedupe',
                subtitle: 'Hapus duplikasi suara di mode Rapat Online',
                value: settings.echoDedupeEnabled,
                onChanged: notifier.setEchoDedupeEnabled,
              ),
              _SettingsSwitch(
                icon: Icons.timer_outlined,
                label: 'Auto-stop saat diam',
                subtitle: settings.autoStopMinutes != null
                    ? 'Berhenti setelah ${settings.autoStopMinutes} menit'
                    : 'Nonaktif',
                value: settings.autoStopMinutes != null,
                onChanged: (v) => notifier.setAutoStopMinutes(v ? 5 : null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Informasi',
            children: [
              _SettingsTile(
                icon: Icons.keyboard_outlined,
                label: 'Pintasan Global',
                subtitle: 'Ctrl+Shift+R: Mulai/Berhenti\nCtrl+Shift+P: Jeda/Lanjutkan',
                trailing: Icon(Icons.info_outline, color: colors.textTertiary, size: 18),
              ),
              _SettingsTile(
                icon: Icons.shield_outlined,
                label: 'Privacy Report',
                subtitle: 'Lihat aktivitas jaringan',
                trailing: Icon(Icons.chevron_right, color: colors.textTertiary),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyReportScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.analytics_outlined,
                label: 'Statistik Penggunaan',
                subtitle: 'Total sesi dan jam ditranskrip',
                trailing: Icon(Icons.chevron_right, color: colors.textTertiary),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UsageDashboardScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.system_update_outlined,
                label: 'Periksa Pembaruan',
                subtitle: 'Cek versi terbaru Trareon Transcribe',
                trailing: Icon(Icons.download_outlined, color: colors.textTertiary, size: 18),
                onTap: () => _checkForUpdates(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _themeLabel(AppThemeMode theme) => switch (theme) {
    AppThemeMode.light => 'Terang',
    AppThemeMode.dark => 'Gelap',
    AppThemeMode.system => 'Sistem',
  };

  Future<void> _checkForUpdates(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final checker = UpdateChecker();
      final info = await checker.checkForUpdate();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      if (info.isUpdateAvailable) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Pembaruan Tersedia'),
            content: Text('Versi ${info.latestVersion} tersedia.\nVersi saat ini: ${info.currentVersion}'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Nanti')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Versi terbaru sudah terinstall.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: colors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: colors.text, fontSize: 14)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: colors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: colors.text, fontSize: 14)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.primary,
          ),
        ],
      ),
    );
  }
}

class _CompactDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  const _CompactDropdown({
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        underline: const SizedBox(),
        dropdownColor: colors.surface,
        style: TextStyle(color: colors.text, fontSize: 13),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(labelBuilder(item)),
        )).toList(),
        onChanged: (item) {
          if (item != null) onChanged(item);
        },
      ),
    );
  }
}
