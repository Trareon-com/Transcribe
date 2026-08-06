import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trascribe/widgets/resource_hud.dart';
import 'package:trascribe/state/session_model.dart';

void main() {
  testWidgets('recording state shows Merekam… label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResourceHud(
            lifecycle: SessionLifecycle.recording,
            segmentsCount: 5,
          ),
        ),
      ),
    );

    expect(find.text('Merekam…'), findsOneWidget);
    expect(find.text('5 segmen'), findsOneWidget);
  });

  testWidgets('paused state shows Dijeda label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResourceHud(
            lifecycle: SessionLifecycle.paused,
            segmentsCount: 3,
          ),
        ),
      ),
    );

    expect(find.text('Dijeda'), findsOneWidget);
    expect(find.text('3 segmen'), findsOneWidget);
  });

  testWidgets('idle state shows Siap label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResourceHud(
            lifecycle: SessionLifecycle.idle,
            segmentsCount: 0,
          ),
        ),
      ),
    );

    expect(find.text('Siap'), findsOneWidget);
    expect(find.text('0 segmen'), findsOneWidget);
  });

  testWidgets('stopped state shows Berhenti label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResourceHud(
            lifecycle: SessionLifecycle.stopped,
            segmentsCount: 10,
          ),
        ),
      ),
    );

    expect(find.text('Berhenti'), findsOneWidget);
  });
}
