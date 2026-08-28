enum OnboardingGateHint { connectProvider, downloadModel, grantPermissions }

class OnboardingStepGate {
  const OnboardingStepGate({required this.ready, this.hint});

  final bool ready;
  final OnboardingGateHint? hint;
}

OnboardingStepGate evaluateOnboardingStepGate({
  required int step,
  required bool permissionsReady,
  required ({bool usesLocalModel, bool ready}) asr,
  required ({bool enabled, bool usesLocalModel, bool ready}) summary,
}) {
  if (step == 3) {
    return OnboardingStepGate(
      ready: permissionsReady,
      hint: permissionsReady ? null : OnboardingGateHint.grantPermissions,
    );
  }
  if (step != 1) return const OnboardingStepGate(ready: true);

  final effectiveSummaryReady = !summary.enabled || summary.ready;
  if (asr.ready && effectiveSummaryReady) {
    return const OnboardingStepGate(ready: true);
  }

  final localDownloadMissing =
      (asr.usesLocalModel && !asr.ready) ||
      (summary.enabled && summary.usesLocalModel && !summary.ready);
  return OnboardingStepGate(
    ready: false,
    hint: localDownloadMissing
        ? OnboardingGateHint.downloadModel
        : OnboardingGateHint.connectProvider,
  );
}
