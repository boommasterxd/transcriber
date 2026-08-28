import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/effects.dart';
import 'package:transcriber/ui/widgets/waveforms.dart';

import 'widget_test_helpers.dart';

void main() {
  testWidgets('PulseRingHero keeps animated content in a repaint boundary', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(const PulseRingHero(size: 96, ringSize: 110)),
    );

    expect(
      find.descendant(
        of: find.byType(PulseRingHero),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    expect(find.byType(EqWave), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
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
