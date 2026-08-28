import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/todo_tile.dart';

import 'widget_test_helpers.dart';

void main() {
  testWidgets('TodoTile displays incomplete item and toggles on tap', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(
      themed(
        TodoTile(text: 'Send report', done: false, onToggle: () => toggles++),
      ),
    );

    expect(find.text('Send report'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(
      tester.widget<Text>(find.text('Send report')).style?.decoration,
      isNull,
    );
    await tester.tap(find.text('Send report'));
    expect(toggles, 1);
  });

  testWidgets('TodoTile displays completed item with check and line-through', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(const TodoTile(text: 'Send report', done: true, onToggle: _noop)),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Send report')).style?.decoration,
      TextDecoration.lineThrough,
    );
    await tester.pump(const Duration(milliseconds: 220));
  });
}

void _noop() {}
