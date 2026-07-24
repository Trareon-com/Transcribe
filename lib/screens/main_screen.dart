import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_model.dart';
import '../theme/app_colors.dart';
import '../widgets/mode_selector.dart';
import '../widgets/resource_hud.dart';
import '../widgets/stream_toggle.dart';
import '../widgets/transcript_view.dart';
import '../widgets/vu_meter.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);
    final isRecording = session.lifecycle == SessionLifecycle.recording;

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
                  FilledButton.icon(
                    onPressed: () => isRecording ? notifier.stop() : notifier.start(),
                    icon: Icon(isRecording ? Icons.stop : Icons.mic),
                    label: Text(isRecording ? 'Stop' : 'Mulai'),
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
