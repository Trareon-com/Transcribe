import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/screens/main_screen.dart';
import 'package:transcribe/state/settings_model.dart';

import '../mocks/mock_rust_bridge.dart';

void main() {
  testWidgets('quality toggle opens download dialog when model unavailable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rustBridgeProvider.overrideWithValue(MockRustBridge()),
        ],
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The quality toggle shows "Akurat" or "Cepat". Default is "Cepat".
    await tester.tap(find.text('Cepat'));
    // Pump through the dialog's async download timers
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.textContaining('Mengunduh model'), findsOneWidget);
  });
}
