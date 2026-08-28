import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/model_tile.dart';

import 'widget_test_helpers.dart';

void main() {
  _registerModelTileTests();
  _registerSelectionTest();
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
          title: 'gpt-transcribe',
          subtitle: 'OpenAI',
          leading: const Icon(Icons.mic),
          leadingColor: Colors.red,
          badge: const Text('Recommended'),
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

void _registerSelectionTest() {
  testWidgets('ModelTile omits bottom border for last item', (tester) async {
    await tester.pumpWidget(
      themed(
        const ModelTile(
          title: 'Model',
          subtitle: 'Google Gemini',
          isLast: true,
          trailing: SizedBox.shrink(),
        ),
      ),
    );

    final tile = tester.widget<Container>(find.byType(Container).first);
    expect((tile.decoration! as BoxDecoration).border, isNull);
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
    final containers = tester.widgetList<Container>(find.byType(Container));
    expect(containers.length, greaterThanOrEqualTo(2));
  });
}
