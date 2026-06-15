import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../state/connections_controller.dart';
import '../../../state/model_manager_controller.dart';
import '../../../state/settings_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/effects.dart';
import '../settings/widgets/appearance_section.dart';
import '../settings/widgets/language_section.dart';
import '../settings/widgets/privacy_section.dart';
import '../settings/widgets/summary_section.dart';
import '../settings/widgets/transcription_section.dart';

/// First-run setup wizard. Five steps that configure the app up-front, reusing
/// the same per-stage settings sections so transcription and summary are chosen
/// independently (local or cloud), exactly like in Settings.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const _stepCount = 5;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _step = 0;

  static const _slide = Duration(milliseconds: 320);
  static const _curve = Curves.easeOutCubic;

  bool get _isLast => _step == OnboardingScreen._stepCount - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      ref.read(settingsControllerProvider.notifier).completeOnboarding();
    } else {
      _pageController.nextPage(duration: _slide, curve: _curve);
    }
  }

  void _prev() => _pageController.previousPage(duration: _slide, curve: _curve);
  void _finish() => ref.read(settingsControllerProvider.notifier).completeOnboarding();

  /// A model step may only advance once it's functionally configured: an
  /// on-device model downloaded, or a cloud provider connected.
  ({bool ready, String? hint}) _stepGate(AppStrings t) {
    final settings = ref.watch(settingsControllerProvider);
    final connections = ref.watch(connectionsControllerProvider);
    final manager = ref.watch(modelManagerControllerProvider);
    final german = t.isDe;
    final connectHint = german ? 'Verbinde einen Anbieter, um fortzufahren.' : 'Connect a provider to continue.';
    final downloadHint = german ? 'Lade das Modell herunter, um fortzufahren.' : 'Download the model to continue.';

    switch (_step) {
      case 1: // transcription
        final ready = settings.asrMode.isLocal || (connections[settings.asrProvider] ?? false);
        return (ready: ready, hint: ready ? null : connectHint);
      case 2: // summary
        if (settings.summaryMode.isLocal) {
          final ready = manager.gemmaStatus(settings.gemmaModelId).isDownloaded;
          return (ready: ready, hint: ready ? null : downloadHint);
        }
        final ready = connections[settings.summaryProvider] ?? false;
        return (ready: ready, hint: ready ? null : connectHint);
      default:
        return (ready: true, hint: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final gate = _stepGate(t);

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
                step: _step,
                count: OnboardingScreen._stepCount,
                showBack: _step > 0,
                // No skip: setup must be functionally completed to proceed.
                showSkip: false,
                skipLabel: t.obSkip,
                onBack: _prev,
                onSkip: _finish,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _step = i),
                  children: [
                    for (var i = 0; i < OnboardingScreen._stepCount; i++)
                      SingleChildScrollView(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                              child: _stepContentFor(i, t),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: gate.ready
                      ? PillButton(
                          label: _isLast ? t.obStart : t.obNext,
                          trailingIcon: Icons.arrow_forward_rounded,
                          onTap: _next,
                        )
                      : Container(
                          height: 56,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 16, color: palette.muted),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  gate.hint ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: palette.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepContentFor(int step, AppStrings t) {
    switch (step) {
      case 0:
        return _WelcomeStep(strings: t);
      case 1:
        return _StepBody(
          title: t.obTranscribeT,
          subtitle: t.obTranscribeS,
          child: const TranscriptionSection(),
        );
      case 2:
        return _StepBody(
          title: t.obSummaryT,
          subtitle: t.obSummaryS,
          child: const SummarySection(),
        );
      case 3:
        return _StepBody(
          title: t.obLookT,
          subtitle: t.obLookS,
          child: Column(
            children: const [
              LanguageSection(),
              SizedBox(height: 12),
              AppearanceSection(),
            ],
          ),
        );
      case 4:
      default:
        return _StepBody(
          title: t.obPrivacyT,
          subtitle: t.obPrivacyS,
          child: Column(
            children: [
              const PrivacySection(),
              const SizedBox(height: 24),
              _ReadyBanner(strings: t),
            ],
          ),
        );
    }
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.step,
    required this.count,
    required this.showBack,
    required this.showSkip,
    required this.skipLabel,
    required this.onBack,
    required this.onSkip,
  });

  final int step;
  final int count;
  final bool showBack;
  final bool showSkip;
  final String skipLabel;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: Row(
          children: [
            if (showBack)
              IconCircleButton(icon: Icons.arrow_back_ios_new_rounded, size: 38, onTap: onBack)
            else
              const SizedBox(width: 38),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 7,
                        width: i == step ? 26 : 7,
                        decoration: BoxDecoration(
                          color: i == step ? palette.accent : palette.line2,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (showSkip)
              GestureDetector(
                onTap: onSkip,
                child: Text(
                  skipLabel,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: palette.muted),
                ),
              )
            else
              const SizedBox(width: 38),
          ],
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.title, required this.subtitle, required this.child});
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
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: palette.ink),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        const PulseRingHero(size: 104, ringSize: 110),
        const SizedBox(height: 22),
        Text(
          strings.obWelcomeT,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: palette.ink),
        ),
        const SizedBox(height: 10),
        Text(
          strings.obWelcomeS,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: palette.muted),
        ),
        const SizedBox(height: 30),
        _TimelineRow(icon: Icons.ios_share_rounded, title: strings.obHiw1T, sub: strings.obHiw1S, connect: true),
        _TimelineRow(icon: Icons.graphic_eq_rounded, title: strings.obHiw2T, sub: strings.obHiw2S, connect: true),
        _TimelineRow(icon: Icons.auto_awesome_outlined, title: strings.obHiw3T, sub: strings.obHiw3S, connect: false),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.icon, required this.title, required this.sub, required this.connect});
  final IconData icon;
  final String title;
  final String sub;
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
              decoration: BoxDecoration(color: palette.accentSoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 21, color: palette.accent),
            ),
            if (connect) Container(width: 2, height: 26, color: palette.line2),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: palette.ink)),
                Text(sub, style: TextStyle(fontSize: 13, color: palette.muted)),
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
          decoration: BoxDecoration(color: palette.mintSoft, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, size: 36, color: palette.mint),
        ),
        const SizedBox(height: 16),
        Text(
          strings.obReadyT,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: palette.ink),
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
