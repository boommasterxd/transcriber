import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/ui/widgets/buttons.dart';

import 'widget_test_helpers.dart';

void main() {
  _registerPressableTest();
  _registerPillTests();
  _registerIconCircleTest();
  _registerSwatchTest();
}

void _registerPressableTest() {
  testWidgets('PressableScale reports a tap after release', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      themed(
        PressableScale(
          action: (
            label: 'Test action',
            onActivate: () => taps++,
            focusBorderRadius: BorderRadius.circular(20),
            selected: null,
            inMutuallyExclusiveGroup: false,
          ),
          child: const SizedBox(width: 80, height: 40),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SizedBox)),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 120));
    expect(taps, 1);
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

  testWidgets('PillButton activates from keyboard and exposes its label', (
    tester,
  ) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(PillButton(label: 'Continue', onTap: () => taps++)),
    );

    final data = tester.semantics
        .find(find.bySemanticsLabel('Continue'))
        .getSemanticsData();
    expect(data.label, 'Continue');
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focusRing = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(PressableScale),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = focusRing.decoration as BoxDecoration;
    expect(
      decoration.boxShadow!.map((shadow) => shadow.color),
      orderedEquals(AppPalette.light(AppAccent.violet).focusIndicatorColors),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
    semantics.dispose();
  });
}

void _registerIconCircleTest() {
  testWidgets('IconCircleButton exposes its localized name and action', (
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
    final semantics = tester.semantics
        .find(find.bySemanticsLabel('Close'))
        .getSemanticsData();
    expect(semantics.label, 'Close');
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
          strings: AppStrings.of(AppLanguage.en),
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

  testWidgets('accent swatches wrap and remain selectable on narrow screens', (
    tester,
  ) async {
    AppAccent? selected;
    await tester.pumpWidget(
      themed(
        Center(
          child: SizedBox(
            width: 240,
            child: AccentSwatches(
              selected: AppAccent.blue,
              onSelected: (accent) => selected = accent,
              strings: AppStrings.of(AppLanguage.en),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final swatches = find.byType(GestureDetector);
    expect(
      tester.getTopLeft(swatches.last).dy,
      greaterThan(tester.getTopLeft(swatches.first).dy),
    );
    await tester.tap(swatches.last);
    expect(selected, AppAccent.values.last);
  });

  testWidgets('accent swatches expose localized names and keyboard selection', (
    tester,
  ) async {
    AppAccent? selected;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        AccentSwatches(
          selected: AppAccent.violet,
          strings: AppStrings.of(AppLanguage.en),
          onSelected: (accent) => selected = accent,
        ),
      ),
    );

    final violet = tester.semantics
        .find(find.byType(AccentSwatches))
        .getSemanticsData();
    expect(violet.label, 'Accent color');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, AppAccent.blue);
    semantics.dispose();
  });
}
