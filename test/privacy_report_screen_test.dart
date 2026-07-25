import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/screens/privacy_report_screen.dart';
import 'package:trascribe/state/privacy_report_model.dart';

void main() {
  testWidgets('shows zero network calls by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PrivacyReportScreen()),
      ),
    );

    expect(find.text('0 network calls since launch'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
    expect(find.text('Belum ada aktivitas jaringan tercatat.'), findsOneWidget);
  });

  testWidgets('recording a model download updates the count and history', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PrivacyReportScreen()),
      ),
    );

    container.read(privacyReportProvider.notifier).recordModelDownload('tiny');
    await tester.pump();

    expect(find.text('1 network calls since launch'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    expect(find.textContaining('Download model "tiny"'), findsOneWidget);
  });
}
