import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/screens/library_screen.dart';

void main() {
  testWidgets('empty library shows placeholder message', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen()));

    expect(find.text('Belum ada sesi tersimpan.'), findsOneWidget);
  });

  testWidgets('lists sessions and opens export dialog', (WidgetTester tester) async {
    const sessions = [
      SessionSummary(
        id: '1',
        title: 'Rapat Q3',
        date: '2026-07-25',
        durationSeconds: 1800,
        segmentsCount: 42,
      ),
    ];
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen(sessions: sessions)));

    expect(find.text('Rapat Q3'), findsOneWidget);

    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();

    expect(find.text('Export "Rapat Q3"'), findsOneWidget);
    expect(find.text('Markdown'), findsOneWidget);
  });
}
