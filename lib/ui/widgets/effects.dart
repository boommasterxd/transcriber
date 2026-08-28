import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'waveforms.dart';

/// Pulsing concentric rings around an animated equalizer — the processing /
/// onboarding hero.
class PulseRingHero extends StatefulWidget {
  const PulseRingHero({super.key, this.size = 96, this.ringSize});

  final double size;
  final double? ringSize;

  @override
  State<PulseRingHero> createState() => _PulseRingHeroState();
}

class _PulseRingHeroState extends State<PulseRingHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _ring(double phase) {
    final palette = context.palette;
    final ring = widget.ringSize ?? widget.size;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = (_c.value + phase) % 1.0;
        return Opacity(
          opacity: (0.55 * (1 - t)).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.55 + t * 1.15,
            child: Container(
              width: ring,
              height: ring,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // The rings + equalizer animate every frame for the whole processing run.
    // A RepaintBoundary keeps those repaints on their own layer so they don't
    // mark the rest of the screen dirty — important while on-device inference is
    // already competing for CPU.
    return RepaintBoundary(
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _ring(0),
            _ring(0.5),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: palette.accentSoft2,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Center(child: EqWave()),
            ),
          ],
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
      child: const Icon(Icons.check, color: Colors.white, size: 16),
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
              borderRadius: BorderRadius.circular(9999),
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
