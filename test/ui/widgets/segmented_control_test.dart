import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/segmented_control.dart';

import 'widget_test_helpers.dart';

void main() {
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

  testWidgets('single-option segmented control remains centered', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        AnimatedSegmentedControl(
          options: const [SegmentOption('Only')],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      ),
    );

    final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
    expect(align.alignment, Alignment.center);
    expect(find.text('Only'), findsOneWidget);
  });

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
