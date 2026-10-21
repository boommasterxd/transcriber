import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/widgets/effects.dart';

import 'widget_test_helpers.dart';

void main() {
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
