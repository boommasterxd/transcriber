import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../widgets/effects.dart';
import '../../settings/widgets/appearance_section.dart';
import '../../settings/widgets/language_section.dart';
import 'onboarding_models_step.dart';
import 'onboarding_permissions_step.dart';

class OnboardingStepContent extends StatelessWidget {
  const OnboardingStepContent({
    required this.step,
    required this.strings,
    super.key,
  });

  final int step;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => switch (step) {
    0 => _WelcomeStep(strings: strings),
    1 => _StepBody(
      title: strings.obModelsT,
      subtitle: strings.obModelsS,
      child: const OnboardingModelsStep(),
    ),
    2 => _StepBody(
      title: strings.obLookT,
      subtitle: strings.obLookS,
      child: const Column(
        children: [
          LanguageSection(),
          SizedBox(height: 12),
          AppearanceSection(),
        ],
      ),
    ),
    3 => _StepBody(
      title: strings.obPermsT,
      subtitle: strings.obPermsS,
      child: const OnboardingPermissionsStep(),
    ),
    _ => _ReadyBanner(strings: strings),
  };
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5, height: 1.45, color: palette.muted),
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        const SizedBox(height: 8),
        const PulseRingHero(size: 104, ringSize: 110),
        const SizedBox(height: 22),
        Text(
          strings.obWelcomeT,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          strings.obWelcomeS,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: palette.muted),
        ),
        const SizedBox(height: 30),
        _TimelineRow(
          icon: Icons.ios_share_rounded,
          title: strings.obHiw1T,
          subtitle: strings.obHiw1S,
          connect: true,
        ),
        _TimelineRow(
          icon: Icons.graphic_eq_rounded,
          title: strings.obHiw2T,
          subtitle: strings.obHiw2S,
          connect: true,
        ),
        _TimelineRow(
          icon: Icons.auto_awesome_outlined,
          title: strings.obHiw3T,
          subtitle: strings.obHiw3S,
          connect: false,
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.connect,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool connect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 21, color: palette.accent),
            ),
            if (connect) Container(width: 2, height: 26, color: palette.line2),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadyBanner extends StatelessWidget {
  const _ReadyBanner({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: palette.mintSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 36, color: palette.mint),
        ),
        const SizedBox(height: 16),
        Text(
          strings.obReadyT,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          strings.obReadyS,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.45, color: palette.muted),
        ),
      ],
    );
  }
}
