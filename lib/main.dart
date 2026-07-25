import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/main_screen.dart';
import 'screens/setup_wizard_screen.dart';
import 'state/settings_model.dart';
import 'state/models.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: TrascribeApp()));
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
      title: 'Trascribe',
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
