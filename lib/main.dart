import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/main_screen.dart';
import 'screens/setup_wizard_screen.dart';
import 'services/rust_library_loader.dart';
import 'services/tray_service.dart';
import 'src/rust/api.dart' as rust_api;
import 'src/rust/frb_generated.dart';
import 'state/settings_model.dart';
import 'state/models.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init(externalLibrary: tryLoadRustCoreLibrary());
  await rust_api.initLogging();

  // Singleton instance lock (PRD: app must not be launchable twice). A
  // stale lock from a crashed prior process is reclaimed automatically
  // by the Rust side (dead-PID check), so this only blocks a genuinely
  // live second instance.
  try {
    await rust_api.acquireInstanceLock();
  } catch (_) {
    runApp(const _AlreadyRunningApp());
    return;
  }

  // Minimize-to-tray: closing the window hides it instead of quitting,
  // so a live session keeps transcribing in the background.
  await TrayService.instance.init();

  runApp(const ProviderScope(child: TrascribeApp()));
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

/// True once the first-run wizard has completed. Persisted settings-side
/// (AppSettings) once FRB codegen lands; in-memory for now is enough to
/// drive the UI flow.
final firstRunCompleteProvider = StateProvider<bool>((ref) => false);

class TrascribeApp extends ConsumerWidget {
  const TrascribeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final firstRunComplete = ref.watch(firstRunCompleteProvider);

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
      home: firstRunComplete
          ? const MainScreen()
          : SetupWizardScreen(
              onFinished: () => ref.read(firstRunCompleteProvider.notifier).state = true,
            ),
    );
  }
}
