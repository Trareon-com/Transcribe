import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/audio_stream_model.dart';
import '../theme/app_colors.dart';

class VuMeter extends ConsumerWidget {
  const VuMeter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vu = ref.watch(vuLevelProvider);
    final mic = vu.valueOrNull?.micLevel ?? 0.0;
    final speaker = vu.valueOrNull?.speakerLevel ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Level mic',
            value: '${(mic * 100).round()} persen',
            child: _bar(mic, AppColors.micAccent),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            label: 'Level speaker',
            value: '${(speaker * 100).round()} persen',
            child: _bar(speaker, AppColors.spkAccent),
          ),
        ),
      ],
    );
  }

  Widget _bar(double level, Color color) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: level.clamp(0.0, 1.0),
          minHeight: 6,
          color: color,
          backgroundColor: color.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}
