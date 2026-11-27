import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'waveforms.dart';

/// Pulsing concentric rings around an animated equalizer for the processing and
/// onboarding hero.
class PulseRingHero extends StatelessWidget {
  const PulseRingHero({super.key, this.size = 96, this.ringSize});

  final double size;
  final double? ringSize;

  Widget _ring(Color accent, double progress) {
    final ring = ringSize ?? size;
    return Opacity(
      opacity: 0.55 * (1 - progress),
      child: Transform.scale(
        scale: 0.55 + progress * 1.15,
        child: Container(
          width: ring,
          height: ring,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accent.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // The rings + equalizer animate every frame for the whole processing run.
    // A RepaintBoundary keeps those repaints on their own layer so they don't
    // mark the rest of the screen dirty while processing is active.
    return RepaintBoundary(
      child: SizedBox(
        width: 140,
        height: 140,
        child: DecorativeLoop(
          duration: const Duration(seconds: 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: palette.accentSoft2,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Center(child: EqWave()),
          ),
          builder: (context, progress, child) => Stack(
            alignment: Alignment.center,
            children: [
              _ring(palette.accent, progress),
              _ring(palette.accent, (progress + 0.5) % 1.0),
              child!,
            ],
          ),
        ),
      ),
    );
  }
}

/// The two-step Transcription → Summary progress stepper.
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.step1Label,
    required this.step2Label,
    required this.activeStepIsSecond,
  });

  final String step1Label;
  final String step2Label;
  final bool activeStepIsSecond;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget circleDone() => Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: palette.mint, shape: BoxShape.circle),
      child: const Icon(Icons.check, color: Colors.black, size: 16),
    );
    Widget circleSpinner() => SizedBox(
      width: 34,
      height: 34,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        backgroundColor: palette.accentSoft,
        valueColor: AlwaysStoppedAnimation(palette.accent),
      ),
    );
    Widget circlePending() => Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: palette.chip, shape: BoxShape.circle),
      child: Center(
        child: Text(
          '2',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: palette.faint,
          ),
        ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                activeStepIsSecond ? circleDone() : circleSpinner(),
                const SizedBox(height: 7),
                Text(
                  step1Label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.body,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 3,
            width: 36,
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                activeStepIsSecond ? circleSpinner() : circlePending(),
                const SizedBox(height: 7),
                Text(
                  step2Label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
