import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A polished, animated bar representing audio levels with a gradient fill.
class StreamVuMeter extends StatelessWidget {
  final double level;
  final Color accent;

  const StreamVuMeter({
    super.key,
    required this.level,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: level.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Container(
          height: 6,
          decoration: BoxDecoration(
            color: colors.border.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2E7D32), // green
                    const Color(0xFFFFA000), // amber at 70%
                    const Color(0xFFD32F2F), // red at 90%
                  ],
                  stops: const [0.0, 0.7, 0.9],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Legacy wrapper for backward compatibility if needed, 
/// though main_screen now uses _VuRow + StreamVuMeter.
class VuMeter extends StatelessWidget {
  final double micLevel;
  final double speakerLevel;

  const VuMeter({
    super.key,
    this.micLevel = 0,
    this.speakerLevel = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: StreamVuMeter(level: micLevel, accent: Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: StreamVuMeter(level: speakerLevel, accent: Colors.orange)),
      ],
    );
  }
}
