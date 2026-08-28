import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/screens/onboarding/onboarding_step_gate.dart';

void main() {
  const readyAsr = (usesLocalModel: true, ready: true);
  const readySummary = (enabled: true, usesLocalModel: true, ready: true);

  test('allows steps without a readiness requirement', () {
    for (final step in [0, 2, 4]) {
      final gate = evaluateOnboardingStepGate(
        step: step,
        permissionsReady: false,
        asr: (usesLocalModel: true, ready: false),
        summary: (enabled: true, usesLocalModel: true, ready: false),
      );

      expect(gate.ready, isTrue);
      expect(gate.hint, isNull);
    }
  });

  test('requires both permissions on the permissions step', () {
    final blocked = evaluateOnboardingStepGate(
      step: 3,
      permissionsReady: false,
      asr: readyAsr,
      summary: readySummary,
    );
    final ready = evaluateOnboardingStepGate(
      step: 3,
      permissionsReady: true,
      asr: readyAsr,
      summary: readySummary,
    );

    expect(blocked.ready, isFalse);
    expect(blocked.hint, OnboardingGateHint.grantPermissions);
    expect(ready.ready, isTrue);
    expect(ready.hint, isNull);
  });

  test('requests a download when a required local model is missing', () {
    final missingAsr = evaluateOnboardingStepGate(
      step: 1,
      permissionsReady: true,
      asr: (usesLocalModel: true, ready: false),
      summary: readySummary,
    );
    final missingSummary = evaluateOnboardingStepGate(
      step: 1,
      permissionsReady: true,
      asr: readyAsr,
      summary: (enabled: true, usesLocalModel: true, ready: false),
    );

    expect(missingAsr.hint, OnboardingGateHint.downloadModel);
    expect(missingSummary.hint, OnboardingGateHint.downloadModel);
  });

  test('requests a connection when only a cloud stage is unavailable', () {
    final gate = evaluateOnboardingStepGate(
      step: 1,
      permissionsReady: true,
      asr: (usesLocalModel: false, ready: true),
      summary: (enabled: true, usesLocalModel: false, ready: false),
    );

    expect(gate.ready, isFalse);
    expect(gate.hint, OnboardingGateHint.connectProvider);
  });

  test('ignores summary readiness when summaries are disabled', () {
    final gate = evaluateOnboardingStepGate(
      step: 1,
      permissionsReady: true,
      asr: readyAsr,
      summary: (enabled: false, usesLocalModel: true, ready: false),
    );

    expect(gate.ready, isTrue);
    expect(gate.hint, isNull);
  });
}
