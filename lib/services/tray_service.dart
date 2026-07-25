import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Minimize-to-tray (PRD: "Minimize-to-tray menjaga transkrip berjalan
/// background"). Closing the window hides it instead of quitting the
/// process, so a live transcription session keeps running; the tray
/// icon's context menu is the only way to actually quit.
class TrayService with TrayListener, WindowListener {
  static final TrayService instance = TrayService._();
  TrayService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    final iconPath = Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png';
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('Trareon Transcribe');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Buka Trareon Transcribe'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Keluar'),
        ],
      ),
    );
    trayManager.addListener(this);
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
      case 'quit':
        windowManager.setPreventClose(false);
        windowManager.close();
    }
  }

  @override
  void onWindowClose() async {
    final preventClose = await windowManager.isPreventClose();
    if (preventClose) {
      await windowManager.hide();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }
}
