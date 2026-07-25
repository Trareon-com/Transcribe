import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/global_hotkey_service.dart';
import '../state/audio_stream_model.dart';
import '../state/models.dart';
import '../state/session_model.dart';
import '../state/settings_model.dart';
import '../src/rust/session.dart' as rust_session;
import '../theme/app_colors.dart';
import '../widgets/transcript_view.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final GlobalHotkeyService _globalHotkeys = GlobalHotkeyService();
  List<rust_session.SessionRecoverySnapshot> _recoverableSessions = const [];
  bool _loadingRecoveries = true;
  bool _showShortcuts = false;
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _globalHotkeys.init(
      ref.read(sessionProvider.notifier),
      () => ref.read(sessionProvider).lifecycle,
    );
    _loadRecoveries();
  }

  @override
  void dispose() {
    _globalHotkeys.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadRecoveries() async {
    final bridge = ref.read(rustBridgeProvider);
    final recoveries = await bridge.listRecoverableSessions();
    if (!mounted) return;
    setState(() {
      _recoverableSessions = recoveries;
      _loadingRecoveries = false;
    });
  }

  Future<void> _recoverSession(
    BuildContext context,
    WidgetRef ref,
    rust_session.SessionRecoverySnapshot snapshot,
  ) async {
    await ref.read(sessionProvider.notifier).recoverFromSnapshot(snapshot);
    if (!context.mounted) return;
    setState(() {
      _recoverableSessions = _recoverableSessions
          .where((item) => item.sessionId != snapshot.sessionId)
          .toList(growable: false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sesi ${snapshot.sessionId} dipulihkan.')),
    );
  }

  Future<void> _handleStopPressed(BuildContext context, WidgetRef ref) async {
    final segments = ref.read(sessionProvider).segments;
    if (segments.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Berhenti merekam?'),
          content: Text(
            'Sesi ini punya ${segments.length} segmen transkrip. '
            'Sesi akan disimpan otomatis saat berhenti.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Berhenti'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (context.mounted) {
      await ref.read(sessionProvider.notifier).stop();
    }
  }

  Future<void> _toggleStartStop(BuildContext context, WidgetRef ref) async {
    final lifecycle = ref.read(sessionProvider).lifecycle;
    final isActive =
        lifecycle == SessionLifecycle.recording || lifecycle == SessionLifecycle.paused;
    if (isActive) {
      await _handleStopPressed(context, ref);
      return;
    }
    try {
      await ref.read(sessionProvider.notifier).start();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _onExport(BuildContext context) async {
    final session = ref.read(sessionProvider);
    if (session.segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada transkrip untuk diekspor.')),
      );
      return;
    }
    final settings = ref.read(settingsProvider);
    final defaultDir = resolveTilde(settings.libraryPath);
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih folder ekspor',
      initialDirectory: defaultDir,
    );
    if (selectedDir == null) return;
    if (!context.mounted) return;
    try {
      final bridge = ref.read(rustBridgeProvider);
      final title = session.sessionTitle.isNotEmpty
          ? session.sessionTitle
          : 'Sesi ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}';
      await bridge.exportSession(
        segments: session.segments,
        outputDir: selectedDir,
        title: title,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ekspor berhasil ke: $selectedDir')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ekspor gagal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);
    final lifecycle = session.lifecycle;
    final isActive =
        lifecycle == SessionLifecycle.recording || lifecycle == SessionLifecycle.paused;
    final isPaused = lifecycle == SessionLifecycle.paused;
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final vuLevel = ref.watch(vuLevelProvider).valueOrNull;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
            _toggleStartStop(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            _toggleStartStop(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () {
          if (isPaused) notifier.resume();
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          if (isPaused) notifier.resume();
        },
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
              final lp = ref.read(settingsProvider).libraryPath;
              return LibraryScreen(libraryPath: resolveTilde(lp));
            })),
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
              final lp = ref.read(settingsProvider).libraryPath;
              return LibraryScreen(libraryPath: resolveTilde(lp));
            })),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        const SingleActivator(LogicalKeyboardKey.slash, meta: true): () =>
            setState(() => _showShortcuts = !_showShortcuts),
        const SingleActivator(LogicalKeyboardKey.slash, control: true): () =>
            setState(() => _showShortcuts = !_showShortcuts),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.background,
          body: Column(
            children: [
              // Recovery banner
              if (_loadingRecoveries)
                const LinearProgressIndicator(minHeight: 2)
              else if (_recoverableSessions.isNotEmpty)
                Material(
                  color: colors.chipBackground,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.restore_outlined, color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ada ${_recoverableSessions.length} sesi yang bisa dipulihkan.',
                            style: TextStyle(color: colors.text, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _recoverableSessions = const []),
                          child: const Text('Abaikan'),
                        ),
                        FilledButton(
                          onPressed: () => _recoverSession(context, ref, _recoverableSessions.first),
                          child: const Text('Pulihkan'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Header bar
              _HeaderBar(
                session: session,
                isActive: isActive,
                isPaused: isPaused,
                onLibrary: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LibraryScreen()),
                ),
                onSettings: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                onShortcuts: () => setState(() => _showShortcuts = !_showShortcuts),
              ),

              // Control bar
              _ControlBar(
                session: session,
                notifier: notifier,
                isActive: isActive,
                vuMicLevel: vuLevel?.micLevel ?? 0.0,
                vuSpeakerLevel: vuLevel?.speakerLevel ?? 0.0,
                titleController: _titleController,
                onStartStop: () => _toggleStartStop(context, ref),
                onExport: () => _onExport(context),
              ),

              // Transcript
              Expanded(
                child: Stack(
                  children: [
                    TranscriptView(segments: session.segments),
                    if (_showShortcuts)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _ShortcutsPanel(
                          onClose: () => setState(() => _showShortcuts = false),
                        ),
                      ),
                  ],
                ),
              ),

              // Footer
              _FooterBar(
                lifecycle: lifecycle,
                segmentsCount: session.segments.length,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header bar: logo, status pill, system metrics, nav icons
class _HeaderBar extends StatelessWidget {
  final SessionUiState session;
  final bool isActive;
  final bool isPaused;
  final VoidCallback onLibrary;
  final VoidCallback onSettings;
  final VoidCallback onShortcuts;

  const _HeaderBar({
    required this.session,
    required this.isActive,
    required this.isPaused,
    required this.onLibrary,
    required this.onSettings,
    required this.onShortcuts,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.headerBackground,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Logo + Title
          Image.asset('assets/logo.png', width: 28, height: 28),
          const SizedBox(width: 8),
          Text(
            'Trareon Transcribe',
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),

          // Status pill
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.chipBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.statusActive,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPaused ? 'Dijeda' : 'Mendengarkan',
                    style: TextStyle(color: colors.text, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (session.averageConfidence != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Conf ${(session.averageConfidence! * 100).round()}%',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),

          const Spacer(),

          // Nav icons
          _NavIcon(
            icon: Icons.folder_outlined,
            label: 'Library',
            onTap: onLibrary,
          ),
          const SizedBox(width: 12),
          _NavIcon(
            icon: Icons.settings_outlined,
            label: 'Pengaturan',
            onTap: onSettings,
          ),
          const SizedBox(width: 12),
          _NavIcon(
            icon: Icons.keyboard_outlined,
            label: 'Shortcuts',
            onTap: onShortcuts,
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.textSecondary, size: 20),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// Control bar: title, mode selector, mic/spk indicators, start/export
class _ControlBar extends StatelessWidget {
  final SessionUiState session;
  final SessionNotifier notifier;
  final bool isActive;
  final double vuMicLevel;
  final double vuSpeakerLevel;
  final TextEditingController titleController;
  final VoidCallback onStartStop;
  final VoidCallback onExport;

  const _ControlBar({
    required this.session,
    required this.notifier,
    required this.isActive,
    required this.vuMicLevel,
    required this.vuSpeakerLevel,
    required this.titleController,
    required this.onStartStop,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          // Session title
          Expanded(
            flex: 3,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colors.chipBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, color: colors.textTertiary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.sessionTitle.isNotEmpty
                          ? session.sessionTitle
                          : 'Judul sesi...',
                      style: TextStyle(
                        color: session.sessionTitle.isNotEmpty ? colors.text : colors.textTertiary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Mode selector, audio indicators, and action buttons scale down
          // together instead of overflowing when the window is narrower than
          // their combined natural width.
          Expanded(
            flex: 5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModeSelectorCompact(
                    selected: session.config.mode,
                    onChanged: notifier.setMode,
                  ),
                  const SizedBox(width: 12),

                  // MIC indicator
                  _AudioIndicator(
                    icon: Icons.mic,
                    label: 'MIC',
                    enabled: session.config.micEnabled,
                    level: vuMicLevel,
                  ),
                  const SizedBox(width: 8),

                  // SPK indicator
                  _AudioIndicator(
                    icon: Icons.speaker,
                    label: 'SPK',
                    enabled: session.config.speakerEnabled,
                    level: vuSpeakerLevel,
                  ),
                  const SizedBox(width: 12),

                  // Start/Stop button
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: onStartStop,
                      icon: Icon(isActive ? Icons.stop : Icons.play_arrow, size: 18),
                      label: Text(isActive ? 'Stop' : 'Mulai'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? AppColors.warning : colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Export button
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: onExport,
                      icon: Icon(Icons.download_outlined, size: 16, color: colors.text),
                      label: Text('Export', style: TextStyle(color: colors.text)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact mode selector
class _ModeSelectorCompact extends StatelessWidget {
  final SessionMode selected;
  final ValueChanged<SessionMode> onChanged;

  const _ModeSelectorCompact({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: SessionMode.values.map((mode) {
          final isSelected = mode == selected;
          return GestureDetector(
            onTap: () => onChanged(mode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                mode.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : colors.text,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Audio indicator with icon + label + level bar
class _AudioIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final double level;

  const _AudioIndicator({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: enabled ? colors.chipBackground : colors.chipBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: enabled ? colors.primary : colors.textTertiary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: enabled ? colors.primary : colors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          // Level bars
          SizedBox(
            width: 60,
            height: 16,
            child: Row(
              children: List.generate(8, (i) {
                final barLevel = (i + 1) / 8;
                final isActive = enabled && level >= barLevel;
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Container(
                    width: 5,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isActive ? colors.primary : colors.border,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer bar: minimize + diarization info
class _FooterBar extends StatelessWidget {
  final SessionLifecycle lifecycle;
  final int segmentsCount;

  const _FooterBar({required this.lifecycle, required this.segmentsCount});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          // Minimize to tray
          Icon(Icons.keyboard_arrow_down, color: colors.textTertiary, size: 16),
          const SizedBox(width: 4),
          Text(
            'Minimize ke tray',
            style: TextStyle(color: colors.textTertiary, fontSize: 12),
          ),

          const Spacer(),

          // Diarization info
          Icon(Icons.person_outline, color: colors.textTertiary, size: 14),
          const SizedBox(width: 6),
          Text(
            'Diarisasi aktif • Pembicara dipisahkan otomatis (MIC / SPK)',
            style: TextStyle(color: colors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Keyboard shortcuts panel
class _ShortcutsPanel extends StatelessWidget {
  final VoidCallback onClose;

  const _ShortcutsPanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pintasan keyboard',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: colors.textSecondary),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ShortcutRow(label: 'Mulai / Stop merekam', shortcut: 'Cmd+R'),
          _ShortcutRow(label: 'Jeda / Lanjutkan', shortcut: 'Cmd+P'),
          _ShortcutRow(label: 'Buka Library', shortcut: 'Cmd+L'),
          _ShortcutRow(label: 'Buka Pengaturan', shortcut: 'Cmd+,'),
          _ShortcutRow(label: 'Tampilkan panel shortcut', shortcut: 'Cmd+/'),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String label;
  final String shortcut;

  const _ShortcutRow({required this.label, required this.shortcut});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: colors.text, fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.chipBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortcut,
              style: TextStyle(color: colors.textSecondary, fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
