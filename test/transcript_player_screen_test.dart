import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trascribe/screens/transcript_player_screen.dart';
import 'package:trascribe/state/models.dart';

void main() {
  const segments = [
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
  ];

  testWidgets('renders title, transcript, and speed control', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TranscriptPlayerScreen(
          title: 'Rapat Q3',
          durationSeconds: 120,
          segments: segments,
        ),
      ),
    );

    expect(find.text('Rapat Q3'), findsOneWidget);
    expect(find.text('Halo semua'), findsOneWidget);
    expect(find.text('1.0x'), findsOneWidget);
  });

  testWidgets('play button toggles icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TranscriptPlayerScreen(
          title: 'Rapat Q3',
          durationSeconds: 120,
          segments: segments,
        ),
      ),
    );

    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_circle_filled));
    await tester.pump();

    expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
  });

  testWidgets('tapping a segment opens edit dialog and saves new text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TranscriptPlayerScreen(
          title: 'Rapat Q3',
          durationSeconds: 120,
          segments: segments,
        ),
      ),
    );

    await tester.tap(find.text('Halo semua'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Transkrip'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Halo semua, selamat pagi');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Halo semua, selamat pagi'), findsOneWidget);
    expect(find.text('Halo semua'), findsNothing);
  });

  testWidgets('canceling edit dialog keeps original text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TranscriptPlayerScreen(
          title: 'Rapat Q3',
          durationSeconds: 120,
          segments: segments,
        ),
      ),
    );

    await tester.tap(find.text('Halo semua'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'diubah tapi dibatalkan');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('Halo semua'), findsOneWidget);
  });
}
