import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/ui/widgets/buttons.dart';

import 'widget_test_helpers.dart';

void main() {
  _registerPressableTest();
  _registerPillTests();
  _registerIconCircleTest();
  _registerSwatchTest();
}

void _registerPressableTest() {
  testWidgets('PressableScale reports taps and resets after release', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      themed(
        PressableScale(
          onTap: () => taps++,
          child: const SizedBox(width: 80, height: 40),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SizedBox)),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.96,
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 120));
    expect(taps, 1);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });
}

void _registerPillTests() {
  testWidgets('PillButton renders optional icons and invokes callback', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      themed(
        PillButton(
          label: 'Continue',
          icon: Icons.play_arrow,
          trailingIcon: Icons.chevron_right,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(tapped, isTrue);
  });
}

void _registerIconCircleTest() {
  testWidgets('outlined PillButton uses transparent fill and line border', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(PillButton(label: 'Settings', outlined: true, onTap: () {})),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, Colors.transparent);
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNull);
  });

  testWidgets('IconCircleButton exposes icon, size, semantics and callback', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      themed(
        IconCircleButton(
          icon: Icons.close,
          size: 50,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);
    final button = find.descendant(
      of: find.byType(IconCircleButton),
      matching: find.byType(Container),
    );
    final buttonWidget = tester.widget<Container>(button);
    expect(
      buttonWidget.constraints,
      const BoxConstraints.tightFor(width: 50, height: 50),
    );
    final semantics = tester.semantics
        .find(find.byType(PressableScale))
        .getSemanticsData();
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
    await tester.tap(find.byIcon(Icons.close));
    expect(tapped, isTrue);
  });
}

void _registerSwatchTest() {
  testWidgets('AccentSwatches shows selection and reports selected accent', (
    tester,
  ) async {
    AppAccent? selected;
    await tester.pumpWidget(
      themed(
        AccentSwatches(
          selected: AppAccent.violet,
          onSelected: (accent) => selected = accent,
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      find.byType(GestureDetector),
      findsNWidgets(AppAccent.values.length),
    );
    await tester.tap(find.byType(GestureDetector).at(1));
    expect(selected, AppAccent.values[1]);
  });
}
