import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/main_screen.dart';
import 'state/settings_model.dart';
import 'state/models.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: TrascribeApp()));
}

class TrascribeApp extends ConsumerWidget {
  const TrascribeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'Trascribe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.theme == AppThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
      home: const MainScreen(),
    );
  }
}
