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

  testWidgets('search filters sessions by title', (WidgetTester tester) async {
    const sessions = [
      SessionSummary(id: '1', title: 'Rapat Q3 Marketing', date: '2026-07-25', segmentsCount: 10),
      SessionSummary(id: '2', title: 'Wawancara Kandidat', date: '2026-07-24', segmentsCount: 5),
    ];
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen(sessions: sessions)));

    expect(find.text('Rapat Q3 Marketing'), findsOneWidget);
    expect(find.text('Wawancara Kandidat'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'wawancara');
    await tester.pump();

    expect(find.text('Rapat Q3 Marketing'), findsNothing);
    expect(find.text('Wawancara Kandidat'), findsOneWidget);
  });

  testWidgets('search with no matches shows empty state', (WidgetTester tester) async {
    const sessions = [
      SessionSummary(id: '1', title: 'Rapat Q3', date: '2026-07-25', segmentsCount: 10),
    ];
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen(sessions: sessions)));

    await tester.enterText(find.byType(TextField), 'tidak ada yang cocok sama sekali');
    await tester.pump();

    expect(find.text('Tidak ada sesi yang cocok.'), findsOneWidget);
  });

  testWidgets('clearing search restores full list', (WidgetTester tester) async {
    const sessions = [
      SessionSummary(id: '1', title: 'Rapat Q3', date: '2026-07-25', segmentsCount: 10),
    ];
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen(sessions: sessions)));

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(find.text('Rapat Q3'), findsNothing);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(find.text('Rapat Q3'), findsOneWidget);
  });
}
