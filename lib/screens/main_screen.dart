import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_model.dart';
import '../theme/app_colors.dart';
import '../widgets/mode_selector.dart';
import '../widgets/resource_hud.dart';
import '../widgets/shortcuts_panel.dart';
import '../widgets/stream_toggle.dart';
import '../widgets/transcript_view.dart';
import '../widgets/vu_meter.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

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

  void _toggleStartStop(BuildContext context, WidgetRef ref) {
    final lifecycle = ref.read(sessionProvider).lifecycle;
    final isActive =
        lifecycle == SessionLifecycle.recording || lifecycle == SessionLifecycle.paused;
    if (isActive) {
      _handleStopPressed(context, ref);
    } else {
      ref.read(sessionProvider.notifier).start();
    }
  }

  void _togglePauseResume(WidgetRef ref) {
    final notifier = ref.read(sessionProvider.notifier);
    final lifecycle = ref.read(sessionProvider).lifecycle;
    if (lifecycle == SessionLifecycle.paused) {
      notifier.resume();
    } else if (lifecycle == SessionLifecycle.recording) {
      notifier.pause();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);
    final lifecycle = session.lifecycle;
    final isActive =
        lifecycle == SessionLifecycle.recording || lifecycle == SessionLifecycle.paused;
    final isPaused = lifecycle == SessionLifecycle.paused;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
            _toggleStartStop(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            _toggleStartStop(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () =>
            _togglePauseResume(ref),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
            _togglePauseResume(ref),
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LibraryScreen())),
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LibraryScreen())),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        const SingleActivator(LogicalKeyboardKey.slash, meta: true): () =>
            showShortcutsPanel(context),
        const SingleActivator(LogicalKeyboardKey.slash, control: true): () =>
            showShortcutsPanel(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: ModeSelector(
                          selected: session.config.mode,
                          onChanged: notifier.setMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isActive)
                        IconButton(
                          tooltip: isPaused ? 'Lanjutkan' : 'Jeda',
                          icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                          onPressed: () => isPaused ? notifier.resume() : notifier.pause(),
                        ),
                      FilledButton.icon(
                        onPressed: () =>
                            isActive ? _handleStopPressed(context, ref) : notifier.start(),
                        icon: Icon(isActive ? Icons.stop : Icons.mic),
                        label: Text(isActive ? 'Stop' : 'Mulai'),
                      ),
                      IconButton(
                        tooltip: 'Library',
                        icon: const Icon(Icons.folder_open_outlined),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LibraryScreen()),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Pengaturan',
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Keyboard Shortcuts',
                        icon: const Icon(Icons.keyboard_outlined),
                        onPressed: () => showShortcutsPanel(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      StreamToggle(
                        label: 'Mic',
                        enabled: session.config.micEnabled,
                        accent: AppColors.micAccent,
                        onChanged: notifier.toggleMic,
                      ),
                      const SizedBox(width: 16),
                      StreamToggle(
                        label: 'Speaker',
                        enabled: session.config.speakerEnabled,
                        accent: AppColors.spkAccent,
                        onChanged: notifier.toggleSpeaker,
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: VuMeter(),
                ),
                ResourceHud(
                  lifecycle: session.lifecycle,
                  segmentsCount: session.segments.length,
                ),
                const Divider(height: 1),
                Expanded(child: TranscriptView(segments: session.segments)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
