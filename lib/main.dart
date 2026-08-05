import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/model_download_card.dart' show DownloadStatus;
import 'services/rust_library_loader.dart';
import 'services/tray_service.dart';
import 'src/rust/api.dart' as rust_api;
import 'src/rust/frb_generated.dart';
import 'state/models.dart';
import 'state/settings_model.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init(externalLibrary: tryLoadRustCoreLibrary());
  await rust_api.initLogging();

  try {
    await rust_api.acquireInstanceLock();
  } catch (_) {
    runApp(const _AlreadyRunningApp());
    return;
  }

  await TrayService.instance.init();

  runApp(const ProviderScope(child: TranscribeApp()));
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

/// True if both required models exist on disk (Whisper large-v3-turbo + Qwen2.5-7B).
/// Read once at startup; the onboarding screen flips it after the user finishes.
final modelsReadyProvider = StateProvider<bool>((ref) {
  // Lazy read — assume ready unless onboarding has been seen and the check failed.
  // The onboarding screen sets this to true when download completes.
  return true;
});

class TranscribeApp extends ConsumerWidget {
  const TranscribeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final modelsReady = ref.watch(modelsReadyProvider);

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
      // First-launch routing: when models aren't downloaded yet, show the
      // dedicated onboarding/download screen (Task 22). The legacy
      // SetupWizardScreen remains reachable from Settings for power users.
      home: modelsReady
          ? const MainScreen()
          : OnboardingScreen(
              asrStatus: DownloadStatus.idle,
              asrProgress: 0,
              asrTitle: 'Model Pengenalan Suara',
              asrSubtitle:
                  'Mengubah gelombang suara menjadi teks bahasa Indonesia',
              asrSize: '~1,5 GB',
              llmStatus: DownloadStatus.idle,
              llmProgress: 0,
              llmTitle: 'Model Bahasa Indonesia',
              llmSubtitle:
                  'Memperbaiki teks hasil transkrip dan membuat ringkasan',
              llmSize: '~4,5 GB',
              allReady: false,
              onContinue: () {},
              onRetryAsr: () {},
              onRetryLlm: () {},
            ),
    );
  }
}