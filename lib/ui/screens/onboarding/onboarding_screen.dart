import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/connections_controller.dart';
import '../../../state/model_manager_controller.dart';
import '../../../state/settings_controller.dart';
import 'onboarding_step_gate.dart';
import 'widgets/onboarding_layout.dart';
import 'widgets/onboarding_permissions_step.dart';

/// First-run setup wizard for models, appearance, permissions, and completion.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _slide = Duration(milliseconds: 320);
  static const _curve = Curves.easeOutCubic;

  final PageController _pageController = PageController();
  int _step = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == OnboardingLayout.stepCount - 1) {
      ref.read(settingsControllerProvider.notifier).completeOnboarding();
      return;
    }
    _pageController.nextPage(duration: _slide, curve: _curve);
  }

  void _previous() =>
      _pageController.previousPage(duration: _slide, curve: _curve);

  OnboardingStepGate _gate() {
    final settings = ref.watch(settingsControllerProvider);
    final connections = ref.watch(connectionsControllerProvider);
    final models = ref.watch(modelManagerControllerProvider);
    final asrReady = settings.asrMode.isLocal
        ? models.whisperStatus(settings.whisperModelId).isDownloaded
        : (connections[settings.asrProvider] ?? false);
    final summaryReady = settings.summaryMode.isLocal
        ? models.gemmaStatus(settings.gemmaModelId).isDownloaded
        : (connections[settings.summaryProvider] ?? false);
    return evaluateOnboardingStepGate(
      step: _step,
      permissionsReady: ref.watch(onboardingPermissionsReadyProvider),
      asr: (usesLocalModel: settings.asrMode.isLocal, ready: asrReady),
      summary: (
        enabled: settings.summarizeEnabled,
        usesLocalModel: settings.summaryMode.isLocal,
        ready: summaryReady,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OnboardingLayout(
    controller: _pageController,
    step: _step,
    strings: ref.watch(stringsProvider),
    gate: _gate(),
    navigation: (
      back: _previous,
      next: _next,
      pageChanged: (step) => setState(() => _step = step),
    ),
  );
}
