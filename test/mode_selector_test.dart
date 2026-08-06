import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trascribe/widgets/mode_selector.dart';
import 'package:trascribe/state/models.dart';

void main() {
  testWidgets('renders all three modes', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModeSelector(
            selected: SessionMode.online,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Webinar'), findsOneWidget);
    expect(find.text('Rapat Online'), findsOneWidget);
    expect(find.text('Rapat Offline'), findsOneWidget);
  });

  testWidgets('tapping mode calls onChanged', (WidgetTester tester) async {
    SessionMode? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModeSelector(
            selected: SessionMode.online,
            onChanged: (m) => tapped = m,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rapat Offline'));
    await tester.pump();

    expect(tapped, SessionMode.offline);
  });

  testWidgets('tapping webinar changes to webinar mode', (WidgetTester tester) async {
    SessionMode? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModeSelector(
            selected: SessionMode.offline,
            onChanged: (m) => tapped = m,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Webinar'));
    await tester.pump();

    expect(tapped, SessionMode.webinar);
  });
}
