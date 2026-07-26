import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/audio_stream_model.dart';
import '../state/session_model.dart';
import '../theme/app_colors.dart';

/// Animated audio level bar with smooth transitions & distinct mic/spk colors.
class VuMeter extends ConsumerWidget {
  const VuMeter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vu = ref.watch(vuLevelProvider);
    final session = ref.watch(sessionProvider);
    final micEnabled = session.config.micEnabled;
    final speakerEnabled = session.config.speakerEnabled;

    final mic = micEnabled ? (vu.valueOrNull?.micLevel ?? 0.0) : 0.0;
    final speaker = speakerEnabled ? (vu.valueOrNull?.speakerLevel ?? 0.0) : 0.0;

    return Row(
      children: [
        Expanded(child: _AudioBar(
          icon: Icons.mic,
          label: 'MIC',
          level: mic,
          enabled: micEnabled,
          color: const Color(0xFF2E7D32), // green — mic
        )),
        const SizedBox(width: 8),
        Expanded(child: _AudioBar(
          icon: Icons.speaker,
          label: 'SPK',
          level: speaker,
          enabled: speakerEnabled,
          color: const Color(0xFFE65100), // orange — speaker
        )),
      ],
    );
  }
}

class _AudioBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final double level;
  final bool enabled;
  final Color color;

  const _AudioBar({
    required this.icon,
    required this.label,
    required this.level,
    required this.enabled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: enabled ? colors.chipBackground : colors.chipBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: enabled ? color : colors.textTertiary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: enabled ? color : colors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: level.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 80),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    color: enabled ? color : colors.border,
                    backgroundColor: colors.border.withValues(alpha: 0.3),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
