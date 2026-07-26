import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/usage_dashboard_screen.dart';

void main() {
  testWidgets('shows zero state by default', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: UsageDashboardScreen()));

    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('0.0'), findsOneWidget);
    expect(find.text('Belum ada data sesi tersimpan.'), findsOneWidget);
  });

  testWidgets('renders provided stats', (WidgetTester tester) async {
    const stats = UsageStats(
      totalSessions: 12,
      totalMinutesTranscribed: 150,
      totalSegments: 340,
      sessionsByMode: {'Rapat Online': 8, 'Webinar': 4},
    );
    await tester.pumpWidget(const MaterialApp(home: UsageDashboardScreen(stats: stats)));

    expect(find.text('12'), findsOneWidget);
    expect(find.text('2.5'), findsOneWidget);
    expect(find.text('340'), findsOneWidget);
    expect(find.text('Rapat Online'), findsOneWidget);
    expect(find.text('8 sesi'), findsOneWidget);
  });
}
