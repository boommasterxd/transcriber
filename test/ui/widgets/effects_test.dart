import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/effects.dart';

import 'widget_test_helpers.dart';

void main() {
  testWidgets('PulseRingHero follows changes to reduced motion', (
    tester,
  ) async {
    final dispatcher = tester.platformDispatcher;
    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(themed(const Center(child: PulseRingHero())));
    await tester.pump();
    expect(find.byType(PulseRingHero), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);

    dispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(2));

    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('StepIndicator shows spinner and pending second step initially', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const StepIndicator(
          step1Label: 'Transcription',
          step2Label: 'Summary',
          activeStepIsSecond: false,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.text('Transcription'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
  });

  testWidgets('StepIndicator marks first step done while second is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const StepIndicator(
          step1Label: 'Transcription',
          step2Label: 'Summary',
          activeStepIsSecond: true,
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });
}
