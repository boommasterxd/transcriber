import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/screens/onboarding/onboarding_step_gate.dart';

void main() {
  test('welcome, appearance and completion need no readiness condition', () {
    for (final step in [0, 3, 4]) {
      expect(_gate(step: step).ready, isTrue);
      expect(_gate(step: step).hint, isNull);
    }
  });
  test('connection screen requires any successfully connected provider', () {
    expect(_gate(step: 1).hint, OnboardingGateHint.connectProvider);
    expect(_gate(step: 1, connected: true).ready, isTrue);
  });
  test('model screen requires available transcription and enabled summary', () {
    for (final readiness in [(false, true), (true, false), (false, false)]) {
      final gate = _gate(
        step: 2,
        asrReady: readiness.$1,
        summaryReady: readiness.$2,
      );
      expect(gate.ready, isFalse);
      expect(gate.hint, OnboardingGateHint.selectModels);
    }
    expect(_gate(step: 2, asrReady: true, summaryReady: true).ready, isTrue);
    expect(_gate(step: 2, asrReady: true, summaryEnabled: false).ready, isTrue);
  });
}

OnboardingStepGate _gate({
  required int step,
  bool connected = false,
  bool asrReady = false,
  bool summaryEnabled = true,
  bool summaryReady = false,
}) => evaluateOnboardingStepGate(
  step: step,
  hasConnectedProvider: connected,
  asrReady: asrReady,
  summaryEnabled: summaryEnabled,
  summaryReady: summaryReady,
);
