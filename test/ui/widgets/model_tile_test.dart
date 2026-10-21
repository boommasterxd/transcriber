import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/model_tile.dart';

import 'widget_test_helpers.dart';

void main() {
  _registerModelTileTests();
  _registerSelectionIndicatorTest();
}

void _registerModelTileTests() {
  testWidgets('ModelTile displays content, leading widget, badge and taps', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      themed(
        ModelTile(
          content: const ModelTileContent(
            title: 'gpt-transcribe',
            subtitle: 'OpenAI',
            badge: Text('Recommended'),
          ),
          leading: const ModelTileLeading(
            color: Colors.red,
            child: Icon(Icons.mic),
          ),
          trailing: const Icon(Icons.check),
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('gpt-transcribe'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    await tester.tap(find.text('gpt-transcribe'));
    expect(tapped, isTrue);
  });
}

void _registerSelectionIndicatorTest() {
  testWidgets('SelectionIndicator renders distinct selected states', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const Row(
          children: [
            SelectionIndicator(selected: false),
            SelectionIndicator(selected: true),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
