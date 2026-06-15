import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../state/settings_controller.dart';
import '../../navigation.dart';
import '../../widgets/buttons.dart';
import '../../widgets/effects.dart';
import '../../widgets/surfaces.dart';

/// First-run onboarding. "Get started" completes onboarding (revealing Home);
/// "Choose models first" additionally opens Settings.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: palette.bg,
      body: Column(
        children: [
          const SizedBox(height: 56),
          const _OnboardingHero(),
          Expanded(
            child: FadeEdges(
              topHeight: 22,
              builder: (context, controller) => SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TagPill(text: t.obTag),
                    const SizedBox(height: 16),
                    Text(
                      t.obTitle,
                      style: TextStyle(
                        fontSize: 33,
                        height: 1.12,
                        letterSpacing: -0.5,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t.obSub,
                      style: TextStyle(fontSize: 15.5, height: 1.5, color: palette.muted),
                    ),
                    const SizedBox(height: 22),
                    _Feature(icon: Icons.shield_outlined, title: t.obF1t, subtitle: t.obF1s),
                    const SizedBox(height: 12),
                    _Feature(icon: Icons.bolt_outlined, title: t.obF2t, subtitle: t.obF2s),
                    const SizedBox(height: 12),
                    _Feature(icon: Icons.format_list_bulleted_rounded, title: t.obF3t, subtitle: t.obF3s),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Column(
              children: [
                PillButton(
                  label: t.obCta,
                  trailingIcon: Icons.arrow_forward_rounded,
                  onTap: controller.completeOnboarding,
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    await controller.completeOnboarding();
                    if (context.mounted) await AppNavigator.openSettings(context);
                  },
                  child: Text(
                    t.obModels,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: palette.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 268,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [palette.accent.withValues(alpha: 0.16), palette.accent.withValues(alpha: 0)],
              ),
            ),
          ),
          const PulseRingHero(size: 116, ringSize: 150),
          Positioned(
            top: 44,
            left: 40,
            child: _FloatChip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: palette.coral, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '0:48',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.accent),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: 30,
            child: _FloatChip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: palette.mintSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.check, size: 13, color: palette.mint),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    '3 To-dos',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatChip extends StatelessWidget {
  const _FloatChip({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: palette.shadowLg, blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(color: palette.accentSoft, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: palette.accentDeep),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.accentDeep),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: palette.accentSoft, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, size: 20, color: palette.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink)),
              Text(subtitle, style: TextStyle(fontSize: 13, color: palette.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
