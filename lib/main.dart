import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'screens/main_screen.dart';
import 'services/rust_library_loader.dart';
import 'services/tray_service.dart';
import 'src/rust/api.dart' as rust_api;
import 'src/rust/frb_generated.dart';
import 'state/models.dart';
import 'state/settings_model.dart';
import 'theme/app_theme.dart';

/// Bundled model files (shipped with the installer — no download needed).
const _bundledModels = [
  'ggml-tiny.bin',
  'ggml-base.bin',
  'ggml-large-v3-turbo-q5_0.bin',
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init(externalLibrary: tryLoadRustCoreLibrary());
  await rust_api.initLogging();

  // Singleton instance lock
  try {
    await rust_api.acquireInstanceLock();
  } catch (_) {
    runApp(const _AlreadyRunningApp());
    return;
  }

  // Extract bundled models to app data directory (once — after that
  // the files stay on disk and loading is instant).
  await _ensureBundledModels();

  await TrayService.instance.init();

  runApp(const ProviderScope(child: TrascribeApp()));
}

/// Copies bundled models from Flutter assets to the app's models directory
/// so Rust/whisper-rs can load them via a normal filesystem path.
///
/// Only copies files that don't already exist (checked by name), so after
/// the first launch this function is essentially free — no I/O, no delays.
Future<void> _ensureBundledModels() async {
  final appDir = await getApplicationSupportDirectory();
  final modelsDir = Directory('${appDir.path}/models');
  if (!modelsDir.existsSync()) {
    modelsDir.createSync(recursive: true);
  }

  for (final filename in _bundledModels) {
    final dest = File('${modelsDir.path}/$filename');
    if (dest.existsSync()) continue; // already extracted

    final assetPath = 'rust_core/models/$filename';
    try {
      final data = await rootBundle.load(assetPath);
      await dest.writeAsBytes(data.buffer.asUint8List());
    } catch (e) {
      // Model not bundled in this build variant (e.g. debug/web) —
      // not fatal; the user can download models via the UI.
      print('⚠️  bundled model not found: $assetPath ($e)');
    }
  }
}

class _AlreadyRunningApp extends StatelessWidget {
  const _AlreadyRunningApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Trareon Transcribe sudah berjalan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hanya satu instance Trareon Transcribe yang bisa berjalan pada saat '
                  'yang sama. Tutup jendela ini dan gunakan instance yang '
                  'sudah terbuka.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TrascribeApp extends ConsumerWidget {
  const TrascribeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Trareon Transcribe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (settings.theme) {
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
      },
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeInOut,
      // Models are bundled — no setup wizard needed.
      // User can switch between ⚡ base and 🎯 q5_0 from the main screen header.
      home: const MainScreen(),
    );
  }
}
