import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/theme/app_colors.dart';
import 'package:transcribe/widgets/stream_toggle.dart';

void main() {
  testWidgets('exposes a merged semantic node with the label and switch', (
    WidgetTester tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamToggle(
            label: 'Mic',
            enabled: true,
            accent: AppColors.micAccent,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Mic'), findsOneWidget);

    final semantics = tester.getSemantics(find.byType(StreamToggle));
    expect(semantics.label, contains('Mic'));

    handle.dispose();
  });
}
