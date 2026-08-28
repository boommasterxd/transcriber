import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/screens/onboarding/onboarding_step_gate.dart';

void main() {
  test('allows steps without a readiness requirement', () {
    for (final step in [0, 2, 4]) {
      final gate = evaluateOnboardingStepGate(
        step: step,
        permissionsReady: false,
        asrReady: false,
        summaryEnabled: true,
        summaryReady: false,
      );

      expect(gate.ready, isTrue);
      expect(gate.hint, isNull);
    }
  });

  test('requires microphone permission on the permissions step', () {
    final blocked = evaluateOnboardingStepGate(
      step: 3,
      permissionsReady: false,
      asrReady: true,
      summaryEnabled: true,
      summaryReady: true,
    );
    final ready = evaluateOnboardingStepGate(
      step: 3,
      permissionsReady: true,
      asrReady: true,
      summaryEnabled: true,
      summaryReady: true,
    );

    expect(blocked.ready, isFalse);
    expect(blocked.hint, OnboardingGateHint.grantPermissions);
    expect(ready.ready, isTrue);
    expect(ready.hint, isNull);
  });

  test('requires connected providers for both enabled cloud stages', () {
    for (final readiness in [(false, true), (true, false), (false, false)]) {
      final gate = evaluateOnboardingStepGate(
        step: 1,
        permissionsReady: true,
        asrReady: readiness.$1,
        summaryEnabled: true,
        summaryReady: readiness.$2,
      );

      expect(gate.ready, isFalse);
      expect(gate.hint, OnboardingGateHint.connectProvider);
    }
  });

  test('allows the cloud step when every enabled stage is connected', () {
    final gate = evaluateOnboardingStepGate(
      step: 1,
      permissionsReady: true,
      asrReady: true,
      summaryEnabled: true,
      summaryReady: true,
    );

    expect(gate.ready, isTrue);
    expect(gate.hint, isNull);
  });

  test('ignores summary readiness when summaries are disabled', () {
    final gate = evaluateOnboardingStepGate(
      step: 1,
      permissionsReady: true,
      asrReady: true,
      summaryEnabled: false,
      summaryReady: false,
    );

    expect(gate.ready, isTrue);
    expect(gate.hint, isNull);
  });
}
