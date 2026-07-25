import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/audio_stream_model.dart';
import '../state/session_model.dart';
import '../theme/app_colors.dart';

class VuMeter extends ConsumerWidget {
  const VuMeter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vu = ref.watch(vuLevelProvider);
    final session = ref.watch(sessionProvider);
    final micEnabled = session.config.micEnabled;
    final speakerEnabled = session.config.speakerEnabled;

    // Zero out levels for disabled sources
    final mic = micEnabled ? (vu.valueOrNull?.micLevel ?? 0.0) : 0.0;
    final speaker = speakerEnabled ? (vu.valueOrNull?.speakerLevel ?? 0.0) : 0.0;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: micEnabled ? 'Level mikrofon' : 'Mikrofon nonaktif',
            value: micEnabled ? '${(mic * 100).round()} persen' : 'nonaktif',
            child: _bar(mic, AppColors.micAccent, dimmed: !micEnabled),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            label: speakerEnabled ? 'Level pengeras suara' : 'Pengeras suara nonaktif',
            value: speakerEnabled ? '${(speaker * 100).round()} persen' : 'nonaktif',
            child: _bar(speaker, AppColors.spkAccent, dimmed: !speakerEnabled),
          ),
        ),
      ],
    );
  }

  Widget _bar(double level, Color color, {bool dimmed = false}) {
    return ExcludeSemantics(
      child: Opacity(
        opacity: dimmed ? 0.3 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: level.clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }
}
