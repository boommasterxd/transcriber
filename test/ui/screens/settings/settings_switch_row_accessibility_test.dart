import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/screens/settings/widgets/settings_switch_row.dart';

import '../../widgets/widget_test_helpers.dart';

void main() {
  testWidgets('settings switch combines its description and toggles by key', (
    tester,
  ) async {
    var enabled = false;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SettingsSwitchRow(
              icon: (
                data: Icons.delete_outline,
                foreground: Colors.black,
                background: Colors.white,
              ),
              content: (
                title: 'Delete audio after processing',
                subtitle: 'Removes only the app-owned working copy',
                subtitleHeight: null,
              ),
              value: enabled,
              onChanged: (value) => setState(() => enabled = value),
            ),
          ),
        ),
      ),
    );

    final data = tester.semantics.find(find.byType(Switch)).getSemanticsData();
    expect(data.label, contains('Delete audio after processing'));
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    semantics.dispose();
  });
}
