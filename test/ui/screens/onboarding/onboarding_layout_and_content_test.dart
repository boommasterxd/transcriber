import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/ui/screens/onboarding/onboarding_step_gate.dart';
import 'package:transcriber/ui/screens/onboarding/widgets/onboarding_layout.dart';
import 'package:transcriber/ui/screens/onboarding/widgets/onboarding_step_content.dart';
import 'package:transcriber/ui/screens/settings/widgets/provider_connect_card.dart';

import 'onboarding_test_support.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.de);
  useGrantedOnboardingPermissions();
  _registerContentTests(strings);
  _registerLayoutTests(strings);
}

void _registerContentTests(AppStrings strings) {
  testWidgets('step content renders all five distinct steps', (tester) async {
    final expected = [
      strings.obWelcomeT,
      strings.obModelsT,
      strings.obLookT,
      strings.obPermsT,
      strings.obReadyT,
    ];
    for (var step = 0; step < OnboardingLayout.stepCount; step++) {
      await pumpOnboardingTestApp(
        tester,
        child: Scaffold(
          body: SingleChildScrollView(
            child: OnboardingStepContent(step: step, strings: strings),
          ),
        ),
      );
      expect(find.text(expected[step]), findsOneWidget);
    }
  });

  testWidgets('cloud step shows both key cards and the privacy notice', (
    tester,
  ) async {
    await pumpOnboardingTestApp(
      tester,
      child: Scaffold(
        body: SingleChildScrollView(
          child: OnboardingStepContent(step: 1, strings: strings),
        ),
      ),
    );

    expect(find.byType(ProviderConnectCard), findsNWidgets(2));
    expect(find.text(strings.privacyStatement), findsOneWidget);
  });
}

void _registerLayoutTests(AppStrings strings) {
  testWidgets('layout forwards next and hides back on the first step', (
    tester,
  ) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    var nextCalls = 0;
    await pumpOnboardingTestApp(
      tester,
      child: OnboardingLayout(
        controller: controller,
        step: 0,
        strings: strings,
        gate: const OnboardingStepGate(ready: true),
        navigation: (back: () {}, next: () => nextCalls++, pageChanged: (_) {}),
      ),
    );

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    await tester.tap(find.text(strings.obNext));
    expect(nextCalls, 1);
  });

  testWidgets('layout forwards back and labels the final action', (
    tester,
  ) async {
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    var backCalls = 0;
    var nextCalls = 0;
    await pumpOnboardingTestApp(
      tester,
      child: OnboardingLayout(
        controller: controller,
        step: 4,
        strings: strings,
        gate: const OnboardingStepGate(ready: true),
        navigation: (
          back: () => backCalls++,
          next: () => nextCalls++,
          pageChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.tap(find.text(strings.obStart));
    expect(backCalls, 1);
    expect(nextCalls, 1);
  });

  testWidgets('layout replaces a blocked action with each gate hint', (
    tester,
  ) async {
    final hints = <OnboardingGateHint, String>{
      OnboardingGateHint.connectProvider: strings.obConnectHint,
      OnboardingGateHint.grantPermissions: strings.obPermLocked,
    };
    for (final entry in hints.entries) {
      final controller = PageController(initialPage: 1);
      await pumpOnboardingTestApp(
        tester,
        child: OnboardingLayout(
          controller: controller,
          step: 1,
          strings: strings,
          gate: OnboardingStepGate(ready: false, hint: entry.key),
          navigation: (back: () {}, next: () {}, pageChanged: (_) {}),
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text(strings.obNext), findsNothing);
      controller.dispose();
    }
  });
}
