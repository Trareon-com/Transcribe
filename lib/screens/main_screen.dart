import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_model.dart';
import '../theme/app_colors.dart';
import '../widgets/mode_selector.dart';
import '../widgets/resource_hud.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);
    final lifecycle = session.lifecycle;
    final isActive =
        lifecycle == SessionLifecycle.recording || lifecycle == SessionLifecycle.paused;
    final isPaused = lifecycle == SessionLifecycle.paused;

    return Scaffold(
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
    );
  }
}
