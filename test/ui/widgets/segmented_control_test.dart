import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/segmented_control.dart';

import 'widget_test_helpers.dart';

void main() {
  _registerInteractionTests();
  _registerScaledLabelTests();
}

void _registerInteractionTests() {
  testWidgets('AnimatedSegmentedControl labels icons and changes selection', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      themed(
        AnimatedSegmentedControl(
          options: const [
            SegmentOption('Light', icon: Icons.light_mode),
            SegmentOption('Dark', icon: Icons.dark_mode),
          ],
          selectedIndex: 0,
          onChanged: (index) => selected = index,
        ),
      ),
    );

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.byIcon(Icons.light_mode), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    await tester.tap(find.text('Dark'));
    expect(selected, 1);
  });

  testWidgets('segments activate from keyboard and expose selected state', (
    tester,
  ) async {
    int? selected;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        AnimatedSegmentedControl(
          options: const [SegmentOption('Light'), SegmentOption('Dark')],
          selectedIndex: 0,
          onChanged: (index) => selected = index,
        ),
      ),
    );

    final light = tester.semantics.find(find.text('Light')).getSemanticsData();
    expect(light.label, 'Light');
    expect(light.flagsCollection.isSelected, Tristate.isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, 1);
    semantics.dispose();
  });
}

void _registerScaledLabelTests() {
  for (final withIcons in [false, true]) {
    testWidgets('large labels fit narrow controls with icons=$withIcons', (
      tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        themed(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Center(
              child: SizedBox(
                width: 240,
                child: AnimatedSegmentedControl(
                  options: [
                    SegmentOption(
                      'Deutsch',
                      icon: withIcons ? Icons.language : null,
                    ),
                    SegmentOption(
                      'English',
                      icon: withIcons ? Icons.translate : null,
                    ),
                    SegmentOption(
                      'Automatic',
                      icon: withIcons ? Icons.settings : null,
                    ),
                  ],
                  selectedIndex: 0,
                  onChanged: (index) => selected = index,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final control = find.byType(AnimatedSegmentedControl);
      expect(tester.getSize(control).height, greaterThan(44));
      expect(tester.getSize(control).width, 240);
      await tester.tap(find.text('Automatic'));
      expect(selected, 2);
    });
  }
}
