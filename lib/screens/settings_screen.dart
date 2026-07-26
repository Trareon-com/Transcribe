import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:file_picker/file_picker.dart';

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
        surfaceTintColor: colors.headerBackground,
        scrolledUnderElevation: 0.5,
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SettingsSection(title: 'Tampilan', children: [
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
          ]),
          const SizedBox(height: 12),
          _SettingsSection(title: 'Model & Mode', children: [
            _SettingsTile(
              icon: Icons.psychology_outlined,
              label: 'Model default',
              trailing: _CompactDropdown<String>(
                value: settings.defaultModel,
                items: const ['tiny', 'base', 'small', 'medium', 'large-v3-turbo-q5', 'large-v3-turbo'],
                labelBuilder: (s) => s,
                onChanged: (modelId) {
                  if (!isModelAvailable(modelId, libraryPath: settings.libraryPath)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Model "$modelId" belum diunduh. Unduh lewat Setup Wizard terlebih dahulu.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  notifier.setDefaultModel(modelId);
                },
              ),
            ),
            const _SettingsDivider(),
            _SettingsTile(
              icon: Icons.speed_outlined,
              label: 'Progressive Mode',
              subtitle: 'Hasil cepat tiny (3s) → refine otomatis large-turbo di background',
              trailing: const _BadgeChip(label: 'Coming Soon'),
            ),
            const _SettingsDivider(),
            _SettingsTile(
              icon: Icons.info_outline,
              label: 'Perbandingan Model',
              subtitle: 'ID: tiny 3s · base 10s · small 21s · medium 35s · turbo 56s\n'
                  'EN: tiny 2s · base 3s · small 12s · medium 36s · turbo 56s\n'
                  '🏆 Q5_0 turbo: 548MB, RAM 1.2GB (turun 62%)',
              trailing: const SizedBox.shrink(),
            ),
            const _SettingsDivider(),
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
            const _SettingsDivider(),
            _SettingsTile(
              icon: Icons.translate_outlined,
              label: 'Bahasa',
              trailing: _CompactDropdown<String?>(
                value: settings.language,
                items: const [null, 'id', 'en'],
                labelBuilder: (s) => s == null ? 'Auto-detect' : (s == 'id' ? 'Indonesia' : 'English'),
                onChanged: notifier.setLanguage,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _SettingsSection(title: 'Audio & Suara', children: [
            _SettingsSwitch(
              icon: Icons.graphic_eq_outlined,
              label: 'VAD (deteksi suara)',
              subtitle: 'Filter noise sekitar, hanya rekam saat ada suara',
              value: settings.vadEnabled,
              onChanged: notifier.setVadEnabled,
            ),
            const _SettingsDivider(),
            _SettingsTile(
              icon: Icons.spatial_audio_outlined,
              label: 'Echo Dedupe',
              subtitle: 'Cegah duplikasi transkrip dari MIC dan SPK — aktif otomatis di mode Rapat Online',
              trailing: _InfoBadge(
                message: 'Membandingkan kemiripan audio dari mikrofon dan speaker, lalu menghapus duplikat.',
              ),
            ),
            const _SettingsDivider(),
            _SettingsSwitch(
              icon: Icons.timer_outlined,
              label: 'Auto-Stop saat diam',
              subtitle: settings.autoStopMinutes != null
                  ? 'Berhenti setelah ${settings.autoStopMinutes} menit tanpa suara'
                  : 'Nonaktifkan untuk rekaman manual penuh',
              value: settings.autoStopMinutes != null,
              onChanged: (v) => notifier.setAutoStopMinutes(v ? 5 : null),
            ),
            if (settings.autoStopMinutes != null) ...[
              const _SettingsDivider(),
              _SettingsTile(
                icon: Icons.timer_10_outlined,
                label: 'Durasi diam',
                trailing: _CompactDropdown<int>(
                  value: settings.autoStopMinutes!,
                  items: const [1, 2, 3, 5, 10, 15],
                  labelBuilder: (m) => '$m menit',
                  onChanged: notifier.setAutoStopMinutes,
                ),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          _SettingsSection(title: 'Output & Penyimpanan', children: [
            _SettingsTile(
              icon: Icons.folder_outlined,
              label: 'Folder output',
              subtitle: settings.libraryPath,
              trailing: Icon(Icons.chevron_right, color: colors.textTertiary, size: 18),
              onTap: () => _pickOutputFolder(context, ref),
            ),
            const _SettingsDivider(),
            _SettingsTile(
              icon: Icons.description_outlined,
              label: 'Format ekspor default',
              trailing: _CompactDropdown<String>(
                value: 'markdown',
                items: const ['markdown', 'txt', 'srt', 'vtt', 'html', 'docx', 'json'],
                labelBuilder: (s) => s.toUpperCase(),
                onChanged: (_) {}, // placeholder — bisa ditambah di settings model nanti
              ),
            ),
            const _SettingsDivider(),
            _SettingsTile(
              icon: Icons.storage_outlined,
              label: 'Penyimpanan',
              subtitle: 'Kelola ruang penyimpanan sesi transkrip',
              trailing: TextButton.icon(
                onPressed: () => _showStorageDialog(context),
                icon: Icon(Icons.cleaning_services_outlined, size: 16, color: colors.primary),
                label: Text('Bersihkan', style: TextStyle(color: colors.primary, fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _SettingsSection(title: 'Sistem & Informasi', children: [
            _SettingsTile(
              icon: Icons.keyboard_outlined,
              label: 'Pintasan Keyboard',
              subtitle: 'Ctrl+R: Mulai/Berhenti · Ctrl+P: Jeda/Lanjutkan\nCtrl+L: Library · Ctrl+,: Pengaturan',
              trailing: _InfoBadge(message: 'Tekan Ctrl+/ atau Cmd+/ untuk lihat semua pintasan saat merekam.'),
            ),
            const _SettingsDivider(),
            _SettingsTile(
              icon: Icons.shield_outlined,
              label: 'Laporan Privasi',
              subtitle: 'Lihat aktivitas jaringan — nol panggilan selama transkripsi',
              trailing: Icon(Icons.chevron_right, color: colors.textTertiary, size: 18),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyReportScreen()),
              ),
            ),
            const _SettingsDivider(),
            _SettingsTile(
              icon: Icons.analytics_outlined,
              label: 'Statistik Penggunaan',
              subtitle: 'Total sesi, jam transkripsi, dan model yang digunakan',
              trailing: Icon(Icons.chevron_right, color: colors.textTertiary, size: 18),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UsageDashboardScreen(libraryPath: settings.libraryPath),
                ),
              ),
            ),
            const _SettingsDivider(),
            _SettingsTile(
              icon: Icons.system_update_outlined,
              label: 'Periksa Pembaruan',
              subtitle: 'Cari versi terbaru Trareon Transcribe',
              trailing: Icon(Icons.download_outlined, color: colors.textTertiary, size: 18),
              onTap: () => _checkForUpdates(context),
            ),
          ]),
        ],
      ),
    );
  }

  String _themeLabel(AppThemeMode theme) => switch (theme) {
    AppThemeMode.light => 'Terang',
    AppThemeMode.dark => 'Gelap',
    AppThemeMode.system => 'Sistem',
  };

  Future<void> _pickOutputFolder(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(settingsProvider.notifier);
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih folder output transkrip',
      initialDirectory: ref.read(settingsProvider).libraryPath,
    );
    if (selectedDir != null && context.mounted) {
      await notifier.setLibraryPath(selectedDir);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Folder output: $selectedDir'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showStorageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kelola Penyimpanan'),
        content: const Text('Fitur pembersihan cache dan pengelolaan ruang penyimpanan akan tersedia di versi mendatang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    if (!context.mounted) return;
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
        final downloadUrl = info.downloadUrl;
        final install = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Pembaruan Tersedia'),
            content: Text('Versi ${info.latestVersion} tersedia.\nVersi saat ini: ${info.currentVersion}'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Nanti')),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Unduh'),
              ),
            ],
          ),
        );
        if (install == true && downloadUrl != null) {
          _openUrl(downloadUrl);
        }
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Versi terbaru sudah terinstall'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memeriksa pembaruan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openUrl(String url) {
    try {
      if (Platform.isMacOS) {
        Process.run('open', [url]);
      } else if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', url]);
      } else {
        Process.run('xdg-open', [url]);
      }
    } catch (_) {
      // Silently ignore — user can copy URL manually
    }
  }
}

// ─────────────────────────────────────────────
// Section container (card)
// ─────────────────────────────────────────────
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border, width: 0.5),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Section divider
// ─────────────────────────────────────────────
class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: colors.divider.withValues(alpha: 0.5)),
    );
  }
}

// ─────────────────────────────────────────────
// Standard tile (tappable)
// ─────────────────────────────────────────────
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: colors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: colors.text, fontSize: 14, fontWeight: FontWeight.w500)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: TextStyle(color: colors.textTertiary, fontSize: 12, height: 1.4)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Switch tile
// ─────────────────────────────────────────────
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: colors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: colors.text, fontSize: 14, fontWeight: FontWeight.w500)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: TextStyle(color: colors.textTertiary, fontSize: 12, height: 1.4)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Compact dropdown
// ─────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          dropdownColor: colors.surface,
          icon: Icon(Icons.expand_more, size: 16, color: colors.textTertiary),
          style: TextStyle(color: colors.text, fontSize: 13, fontWeight: FontWeight.w500),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(labelBuilder(item)),
          )).toList(),
          onChanged: (item) {
            if (item != null) onChanged(item);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Coming Soon badge
// ─────────────────────────────────────────────
class _BadgeChip extends StatelessWidget {
  final String label;
  const _BadgeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Color.lerp(colors.primary, Colors.transparent, 0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Info badge (tappable tooltip icon)
// ─────────────────────────────────────────────
class _InfoBadge extends StatelessWidget {
  final String message;
  const _InfoBadge({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      textStyle: TextStyle(color: colors.text, fontSize: 12, height: 1.4),
      padding: const EdgeInsets.all(12),
      preferBelow: false,
      child: Icon(Icons.info_outline, color: colors.textTertiary, size: 18),
    );
  }
}
