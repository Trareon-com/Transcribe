import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/widgets/model_download_dialog.dart';

import '../mocks/mock_rust_bridge.dart';

void main() {
  testWidgets('download dialog shows progress and completes', (tester) async {
    final bridge = MockRustBridge();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModelDownloadDialog(
                context: context,
                bridge: bridge,
                modelId: 'large-v3-turbo',
                modelsDir: '/tmp/models',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Mengunduh model large-v3-turbo...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
