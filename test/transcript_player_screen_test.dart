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
}
