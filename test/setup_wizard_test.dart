import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/screens/setup_wizard_screen.dart';

void main() {
  testWidgets('wizard walks through all 5 steps and calls onFinished', (WidgetTester tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(home: SetupWizardScreen(onFinished: () => finished = true)),
    );

    expect(find.text('1. Deteksi Spesifikasi'), findsOneWidget);
    expect(find.text('Selesai'), findsNothing);

    for (final expectedTitle in [
      '2. Pilih Model',
      '3. Setup Audio',
      '4. Unduh Model',
      '5. Tone Test',
    ]) {
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text(expectedTitle), findsOneWidget);
    }

    expect(finished, isFalse);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('back button disabled on first step, enabled after', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SetupWizardScreen(onFinished: () {})));

    final backButton = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Kembali'));
    expect(backButton.onPressed, isNull);

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    final backButtonAfter = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Kembali'));
    expect(backButtonAfter.onPressed, isNotNull);
  });
}
