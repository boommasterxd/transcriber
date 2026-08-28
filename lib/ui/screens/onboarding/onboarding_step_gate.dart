enum OnboardingGateHint { connectProvider, grantPermissions }

class OnboardingStepGate {
  const OnboardingStepGate({required this.ready, this.hint});

  final bool ready;
  final OnboardingGateHint? hint;
}

OnboardingStepGate evaluateOnboardingStepGate({
  required int step,
  required bool permissionsReady,
  required bool asrReady,
  required bool summaryEnabled,
  required bool summaryReady,
}) {
  if (step == 3) {
    return OnboardingStepGate(
      ready: permissionsReady,
      hint: permissionsReady ? null : OnboardingGateHint.grantPermissions,
    );
  }
  if (step != 1) return const OnboardingStepGate(ready: true);

  final effectiveSummaryReady = !summaryEnabled || summaryReady;
  if (asrReady && effectiveSummaryReady) {
    return const OnboardingStepGate(ready: true);
  }
  return const OnboardingStepGate(
    ready: false,
    hint: OnboardingGateHint.connectProvider,
  );
}
