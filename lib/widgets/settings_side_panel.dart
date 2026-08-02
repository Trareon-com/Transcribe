import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../state/models.dart';
import '../state/settings_model.dart';
import '../theme/app_colors.dart';
import '../screens/privacy_report_screen.dart';
import '../screens/usage_dashboard_screen.dart';

class SettingsSidePanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final bool embedded;

  const SettingsSidePanel({
    super.key,
    this.onClose,
    this.embedded = false,
  });

  @override
  ConsumerState<SettingsSidePanel> createState() => _SettingsSidePanelState();
}

class _SettingsSidePanelState extends ConsumerState<SettingsSidePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (widget.onClose != null) {
      await _animationController.reverse();
      widget.onClose!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    final content = Container(
      width: widget.embedded ? double.infinity : 380,
      decoration: BoxDecoration(
        color: colors.surface,
        border: widget.embedded
            ? null
            : Border(left: BorderSide(color: colors.divider, width: 1)),
      ),
      child: Column(
        children: [
          if (!widget.embedded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: colors.headerBackground,
                border: Border(
                  bottom: BorderSide(color: colors.divider, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Pengaturan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _close,
                    tooltip: 'Tutup',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
                const SizedBox(height: 12),
                _SettingsSection(
                  title: 'Model & Transkripsi',
                  children: [
                    _SettingsTile(
                      icon: Icons.speed_outlined,
                      label: 'Prioritas',
                      subtitle: settings.progressiveEnabled
                          ? 'Akurasi Maksimal (Refine q5)'
                          : 'Kecepatan Tinggi (Hanya base)',
                      trailing: _CompactDropdown<bool>(
                        value: settings.progressiveEnabled,
                        items: const [true, false],
                        labelBuilder: (v) => v ? '🎯 Akurasi' : '⚡ Hemat',
                        onChanged: (v) {
                          if (v &&
                              !isModelAvailable('large-v3-turbo-q5',
                                  libraryPath: settings.libraryPath)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Model Akurasi belum ada. Unduh lewat Setup Wizard.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          notifier.setProgressiveEnabled(v);
                        },
                      ),
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
                        labelBuilder: (s) => s == null
                            ? 'Auto-detect'
                            : (s == 'id' ? 'Indonesia' : 'English'),
                        onChanged: notifier.setLanguage,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  title: 'Audio & Suara',
                  children: [
                    _SettingsSwitch(
                      icon: Icons.graphic_eq_outlined,
                      label: 'VAD (deteksi suara)',
                      subtitle:
                          'Hanya rekam saat ada suara. Berlaku sesi berikutnya.',
                      value: settings.vadEnabled,
                      onChanged: notifier.setVadEnabled,
                    ),
                    const _SettingsDivider(),
                    _SettingsSwitch(
                      icon: Icons.timer_outlined,
                      label: 'Auto-Stop saat diam',
                      subtitle: settings.autoStopMinutes != null
                          ? 'Berhenti setelah ${settings.autoStopMinutes} menit tanpa suara'
                          : 'Nonaktifkan untuk rekaman manual',
                      value: settings.autoStopMinutes != null,
                      onChanged: (v) =>
                          notifier.setAutoStopMinutes(v ? 5 : null),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  title: 'Output & Penyimpanan',
                  children: [
                    _SettingsTile(
                      icon: Icons.folder_outlined,
                      label: 'Folder output',
                      subtitle: settings.libraryPath,
                      trailing: Icon(Icons.chevron_right,
                          color: colors.textTertiary, size: 18),
                      onTap: () async {
                        final dir = await FilePicker.platform.getDirectoryPath(
                          dialogTitle: 'Pilih folder output',
                          initialDirectory: settings.libraryPath,
                        );
                        if (dir != null && dir != settings.libraryPath) {
                          notifier.setLibraryPath(dir);
                        }
                      },
                    ),
                    const _SettingsDivider(),
                    _SettingsTile(
                      icon: Icons.save_alt_outlined,
                      label: 'Format ekspor default',
                      trailing: _CompactDropdown<String>(
                        value: settings.defaultExportFormat,
                        items: const [
                          'markdown',
                          'txt',
                          'json',
                          'srt',
                          'vtt',
                          'html',
                          'docx'
                        ],
                        labelBuilder: (f) => f.toUpperCase(),
                        onChanged: notifier.setDefaultExportFormat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  title: 'Lainnya',
                  children: [
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Laporan Privasi',
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacyReportScreen(),
                        ),
                      ),
                    ),
                    const _SettingsDivider(),
                    _SettingsTile(
                      icon: Icons.analytics_outlined,
                      label: 'Dasbor Penggunaan',
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UsageDashboardScreen(
                              libraryPath: settings.libraryPath),
                        ),
                      ),
                    ),
                    const _SettingsDivider(),
                    _SettingsTile(
                      icon: Icons.info_outlined,
                      label: 'Tentang',
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => _showAboutDialog(context, colors),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return content;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 8,
          color: colors.surface,
          child: content,
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppColorSet colors) {
    showAboutDialog(
      context: context,
      applicationName: 'Trareon Transcribe',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.mic, size: 48, color: Colors.teal),
      children: [
        const Text('Transkripsi offline, privasi terjamin.'),
        const SizedBox(height: 16),
        const Text('Dibangun dengan Flutter + Rust (whisper.cpp)'),
      ],
    );
  }

  String _themeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Terang';
      case AppThemeMode.dark:
        return 'Gelap';
      case AppThemeMode.system:
        return 'Sistem';
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Divider(
      height: 1,
      thickness: 1,
      color: colors.divider,
      indent: 56,
      endIndent: 16,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.trailing,
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            trailing,
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
    return _SettingsTile(
      icon: icon,
      label: label,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items
              .map((it) => DropdownMenuItem<T>(
                    value: it,
                    child: Text(
                      labelBuilder(it),
                      style: TextStyle(color: colors.text, fontSize: 12),
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, size: 16, color: colors.textTertiary),
          dropdownColor: colors.surfaceElevated,
        ),
      ),
    );
  }
}
