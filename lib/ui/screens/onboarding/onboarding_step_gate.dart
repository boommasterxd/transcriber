enum OnboardingGateHint { connectProvider, selectModels }

class OnboardingStepGate {
  const OnboardingStepGate({required this.ready, this.hint});

  final bool ready;
  final OnboardingGateHint? hint;
}

OnboardingStepGate evaluateOnboardingStepGate({
  required int step,
  required bool hasConnectedProvider,
  required bool asrReady,
  required bool summaryEnabled,
  required bool summaryReady,
}) {
  if (step == 1) {
    return OnboardingStepGate(
      ready: hasConnectedProvider,
      hint: hasConnectedProvider ? null : OnboardingGateHint.connectProvider,
    );
  }
  if (step != 2) return const OnboardingStepGate(ready: true);

  final effectiveSummaryReady = !summaryEnabled || summaryReady;
  if (asrReady && effectiveSummaryReady) {
    return const OnboardingStepGate(ready: true);
  }
  return const OnboardingStepGate(
    ready: false,
    hint: OnboardingGateHint.selectModels,
  );
}
