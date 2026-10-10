import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/remote_provider.dart';
import '../../../state/connections_controller.dart';
import '../../../state/remote_models_provider.dart';
import '../../../state/settings_controller.dart';
import 'onboarding_step_gate.dart';
import 'widgets/onboarding_layout.dart';
import 'widgets/onboarding_permissions_step.dart';

/// First-run setup wizard for providers, appearance, permissions, and completion.
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

  Future<void> _next() async {
    if (_step == 1) {
      final connections = ref.read(connectionsControllerProvider);
      final connected = RemoteProviderId.values
          .where((provider) => connections[provider] ?? false)
          .toList();
      if (connected.isEmpty) return;
      final settings = ref.read(settingsControllerProvider);
      final controller = ref.read(settingsControllerProvider.notifier);
      if (!connected.contains(settings.asrProvider)) {
        await controller.setAsrProvider(connected.first);
      }
      if (!connected.contains(settings.summaryProvider)) {
        await controller.setSummaryProvider(connected.first);
      }
      if (!mounted || _step != 1) return;
    }
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
    return evaluateOnboardingStepGate(
      step: _step,
      hasConnectedProvider: connections.values.any((connected) => connected),
      permissionsReady: ref.watch(onboardingPermissionsReadyProvider),
      asrReady:
          _step == 2 &&
          _modelReady(
            settings.asrProvider,
            settings.asrModelId(settings.asrProvider),
            true,
          ),
      summaryEnabled: settings.summarizeEnabled,
      summaryReady:
          _step == 2 &&
          settings.summarizeEnabled &&
          _modelReady(
            settings.summaryProvider,
            settings.summaryModelId(settings.summaryProvider),
            false,
          ),
    );
  }

  bool _modelReady(
    RemoteProviderId provider,
    String modelId,
    bool transcription,
  ) {
    if (!(ref.watch(connectionsControllerProvider)[provider] ?? false)) {
      return false;
    }
    final catalog = ref.watch(
      remoteModelsProvider((
        provider: provider,
        forTranscription: transcription,
      )),
    );
    if (catalog.isLoading || catalog.hasError) return false;
    return catalog.asData?.value.any((model) => model.id == modelId) ?? false;
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
