import 'package:flutter/material.dart';

import '../widgets/settings_side_panel.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: const SettingsSidePanel(embedded: true),
    );
  }
}
