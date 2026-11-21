import 'dart:ui' show CheckedState;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:transcriber/ui/widgets/todo_tile.dart';

import 'widget_test_helpers.dart';

void main() {
  testWidgets(
    'TodoTile keeps checked semantics in sync with keyboard and tap',
    (tester) async {
      const label = 'Send report';
      var done = false;
      await tester.pumpWidget(
        themed(
          StatefulBuilder(
            builder: (context, setState) => TodoTile(
              text: label,
              done: done,
              onToggle: () => setState(() => done = !done),
            ),
          ),
        ),
      );

      final item = find.bySemanticsLabel(label);
      expect(item, findsOneWidget);
      _expectChecked(tester, item, checked: false);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      _expectChecked(tester, item, checked: true);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      _expectChecked(tester, item, checked: false);

      await tester.tap(item);
      await tester.pumpAndSettle();
      _expectChecked(tester, item, checked: true);
    },
  );
}

void _expectChecked(WidgetTester tester, Finder item, {required bool checked}) {
  final data = tester.getSemantics(item).getSemanticsData();
  expect(
    data.flagsCollection.isChecked,
    checked ? CheckedState.isTrue : CheckedState.isFalse,
  );
  expect(data.flagsCollection.isButton, isFalse);
}
