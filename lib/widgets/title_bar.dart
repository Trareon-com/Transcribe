import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_colors.dart';

/// macOS-style custom title bar with traffic light buttons, app title,
/// theme toggle, and navigation actions.
///
/// On macOS the three coloured dots (red→close, yellow→minimise,
/// green→maximise) are rendered; on other platforms a simple back/close
/// button is shown instead.
class TitleBar extends StatelessWidget {
  final String title;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback? onLibrary;
  final VoidCallback? onSettings;
  final Widget? leading;

  const TitleBar({
    super.key,
    this.title = 'Trareon Transcribe',
    required this.isDark,
    required this.onToggleTheme,
    this.onLibrary,
    this.onSettings,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    final isMacOS = Platform.isMacOS;

    return GestureDetector(
      onDoubleTap: () {
        if (isMacOS) {
          windowManager.maximize();
        }
      },
      onPanStart: (_) {
        windowManager.startDragging();
      },
      child: Container(
        height: 40,
        padding: EdgeInsets.only(
          left: isMacOS ? 12 : 8,
          right: 8,
        ),
        decoration: BoxDecoration(
          color: colors.headerBackground,
          border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            // Leading widget or traffic lights
            if (leading != null)
              leading!
            else if (isMacOS)
              const _MacOSTrafficLights()
            else if (Navigator.of(context).canPop())
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: colors.textSecondary,
              )
            else
              const SizedBox(width: 8),

            const SizedBox(width: 8),

            // App icon + title
            Image.asset('assets/logo.png', width: 20, height: 20, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(),

            // Navigation icons
            if (onLibrary != null)
              _TitleBarAction(
                icon: Icons.folder_outlined,
                tooltip: 'Library',
                onTap: onLibrary!,
              ),
            if (onSettings != null)
              _TitleBarAction(
                icon: Icons.settings_outlined,
                tooltip: 'Pengaturan',
                onTap: onSettings!,
              ),

            // Theme toggle
            _TitleBarAction(
              icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
              onTap: onToggleTheme,
            ),
          ],
        ),
      ),
    );
  }
}

/// macOS-style traffic light buttons (close, minimise, zoom).
/// Since Flutter cannot natively send window commands on macOS Web,
/// we use window_manager for the actual window operations.
class _MacOSTrafficLights extends StatelessWidget {
  const _MacOSTrafficLights();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TrafficDot(
          color: const Color(0xFFFF5F57),
          onTap: () => windowManager.close(),
        ),
        const SizedBox(width: 6),
        _TrafficDot(
          color: const Color(0xFFFFBD2E),
          onTap: () => windowManager.minimize(),
        ),
        const SizedBox(width: 6),
        _TrafficDot(
          color: const Color(0xFF28C840),
          onTap: () => windowManager.maximize(),
        ),
      ],
    );
  }
}

class _TrafficDot extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _TrafficDot({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 1,
              spreadRadius: 0.5,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TitleBarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorSet>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          icon: Icon(icon, size: 18),
          tooltip: tooltip,
          onPressed: onTap,
          padding: EdgeInsets.zero,
          color: colors.textSecondary,
          splashRadius: 16,
        ),
      ),
    );
  }
}
