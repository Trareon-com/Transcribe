import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/screens/library_screen.dart';
import 'package:trascribe/state/models.dart';

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
        segments: [
          TranscriptSegment(
            source: 'mic',
            speaker: 'MIC',
            text: 'Halo semua',
            timestamp: 0,
            duration: 2,
            language: 'id',
            confidence: 0.9,
            isPartial: false,
          ),
        ],
      ),
    ];
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen(sessions: sessions)));

    expect(find.text('Rapat Q3'), findsOneWidget);

    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();

    expect(find.text('Export "Rapat Q3"'), findsOneWidget);
    expect(find.text('Markdown'), findsOneWidget);
  });

  testWidgets('opening a session passes transcript segments to the player', (
    WidgetTester tester,
  ) async {
    const sessions = [
      SessionSummary(
        id: '1',
        title: 'Rapat Q3',
        date: '2026-07-25',
        durationSeconds: 1800,
        segmentsCount: 42,
        segments: [
          TranscriptSegment(
            source: 'mic',
            speaker: 'MIC',
            text: 'Halo semua',
            timestamp: 0,
            duration: 2,
            language: 'id',
            confidence: 0.9,
            isPartial: false,
          ),
        ],
      ),
    ];
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen(sessions: sessions)));

    await tester.tap(find.text('Rapat Q3'));
    await tester.pumpAndSettle();

    expect(find.text('Halo semua'), findsOneWidget);
    expect(find.text('Rapat Q3'), findsWidgets);
  });

  testWidgets('editing a session from the player persists back into the library', (
    WidgetTester tester,
  ) async {
    const sessions = [
      SessionSummary(
        id: '1',
        title: 'Rapat Q3',
        date: '2026-07-25',
        durationSeconds: 1800,
        segmentsCount: 1,
        segments: [
          TranscriptSegment(
            source: 'mic',
            speaker: 'MIC',
            text: 'Halo semua',
            timestamp: 0,
            duration: 2,
            language: 'id',
            confidence: 0.9,
            isPartial: false,
          ),
        ],
      ),
    ];
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen(sessions: sessions)));

    await tester.tap(find.text('Rapat Q3'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Halo semua'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Halo semua, selamat pagi');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rapat Q3'));
    await tester.pumpAndSettle();

    expect(find.text('Halo semua, selamat pagi'), findsOneWidget);
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

  testWidgets('refreshes displayed sessions when parent updates the list', (
    WidgetTester tester,
  ) async {
    const initialSessions = [
      SessionSummary(id: '1', title: 'Rapat Q3', date: '2026-07-25', segmentsCount: 10),
    ];
    const updatedSessions = [
      SessionSummary(id: '2', title: 'Wawancara Kandidat', date: '2026-07-26', segmentsCount: 7),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryScreen(sessions: initialSessions),
      ),
    );

    expect(find.text('Rapat Q3'), findsOneWidget);
    expect(find.text('Wawancara Kandidat'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryScreen(sessions: updatedSessions),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rapat Q3'), findsNothing);
    expect(find.text('Wawancara Kandidat'), findsOneWidget);
  });

  testWidgets('delete removes session and shows undo snackbar', (WidgetTester tester) async {
    const sessions = [
      SessionSummary(id: '1', title: 'Rapat Q3', date: '2026-07-25', segmentsCount: 10),
    ];
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen(sessions: sessions)));

    await tester.tap(find.byTooltip('Hapus'));
    await tester.pump();

    expect(find.text('Rapat Q3'), findsNothing);
    expect(find.textContaining('dihapus'), findsOneWidget);
    expect(find.text('Urungkan'), findsOneWidget);
  });

  testWidgets('undo restores the deleted session', (WidgetTester tester) async {
    const sessions = [
      SessionSummary(id: '1', title: 'Rapat Q3', date: '2026-07-25', segmentsCount: 10),
    ];
    await tester.pumpWidget(const MaterialApp(home: LibraryScreen(sessions: sessions)));

    await tester.tap(find.byTooltip('Hapus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Rapat Q3'), findsNothing);

    await tester.tap(find.text('Urungkan'));
    await tester.pump();

    expect(find.text('Rapat Q3'), findsOneWidget);
  });

  test('share summary includes transcript text when available', () {
    const session = SessionSummary(
      id: '1',
      title: 'Rapat Q3',
      date: '2026-07-25',
      durationSeconds: 1800,
      segmentsCount: 1,
      segments: [
        TranscriptSegment(
          source: 'mic',
          speaker: 'MIC',
          text: 'Halo semua',
          timestamp: 0,
          duration: 2,
          language: 'id',
          confidence: 0.9,
          isPartial: false,
        ),
      ],
    );

    final summaryText = buildSessionShareText(session);
    expect(summaryText, contains('MIC: Halo semua'));
    expect(summaryText, contains('Rapat Q3'));
    expect(summaryText, contains('2026-07-25'));
  });
}
