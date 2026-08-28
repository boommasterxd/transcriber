import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/surfaces.dart';
import '../onboarding_step_gate.dart';
import 'onboarding_step_content.dart';

typedef OnboardingNavigation = ({
  VoidCallback back,
  VoidCallback next,
  ValueChanged<int> pageChanged,
});

class OnboardingLayout extends StatelessWidget {
  const OnboardingLayout({
    required this.controller,
    required this.step,
    required this.strings,
    required this.gate,
    required this.navigation,
    super.key,
  });

  static const stepCount = 5;

  final PageController controller;
  final int step;
  final AppStrings strings;
  final OnboardingStepGate gate;
  final OnboardingNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.accentSoft2, palette.bg],
            stops: const [0, 0.46],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _ProgressBar(
                step: step,
                showBack: step > 0,
                onBack: navigation.back,
              ),
              Expanded(
                child: PageView(
                  controller: controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: navigation.pageChanged,
                  children: [
                    for (var index = 0; index < stepCount; index++)
                      _StepViewport(index: index, strings: strings),
                  ],
                ),
              ),
              _OnboardingFooter(
                gate: gate,
                isLast: step == stepCount - 1,
                strings: strings,
                onNext: navigation.next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepViewport extends StatelessWidget {
  const _StepViewport({required this.index, required this.strings});

  final int index;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => FadeEdges(
    topHeight: 14,
    builder: (context, controller) {
      final content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
            child: OnboardingStepContent(step: index, strings: strings),
          ),
        ),
      );
      if (index != OnboardingLayout.stepCount - 1) {
        return SingleChildScrollView(controller: controller, child: content);
      }
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: controller,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        ),
      );
    },
  );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.step,
    required this.showBack,
    required this.onBack,
  });

  final int step;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: Row(
          children: [
            if (showBack) ...[
              IconCircleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 38,
                onTap: onBack,
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < OnboardingLayout.stepCount;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(width: 6),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        height: 7,
                        decoration: BoxDecoration(
                          color: index <= step ? palette.accent : palette.line2,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.gate,
    required this.isLast,
    required this.strings,
    required this.onNext,
  });

  final OnboardingStepGate gate;
  final bool isLast;
  final AppStrings strings;
  final VoidCallback onNext;

  String _hint() => switch (gate.hint) {
    OnboardingGateHint.connectProvider => strings.obConnectHint,
    OnboardingGateHint.grantPermissions => strings.obPermLocked,
    null => '',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: gate.ready
            ? PillButton(
                label: isLast ? strings.obStart : strings.obNext,
                trailingIcon: Icons.arrow_forward_rounded,
                onTap: onNext,
              )
            : SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: palette.muted,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _hint(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
