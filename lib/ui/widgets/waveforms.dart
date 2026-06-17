import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// Deterministic pseudo-waveform heights (0.2..1.0) used by the players.
List<double> _waveHeights(int count) => List.generate(count, (i) {
      final a = (math.sin(i * 0.6) + 0.55 * math.sin(i * 0.21) + 0.3 * math.sin(i * 1.3)).abs();
      return 0.2 + 0.8 * math.min(1.0, a / 1.6);
    });

/// Animated equalizer used in onboarding / processing hero badges.
class EqWave extends StatefulWidget {
  const EqWave({super.key, this.bars = 7, this.height = 46, this.color});

  final int bars;
  final double height;
  final Color? color;

  @override
  State<EqWave> createState() => _EqWaveState();
}

class _EqWaveState extends State<EqWave> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.palette.accent;
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.bars, (i) {
            final phase = (i * 0.11);
            final t = (math.sin((_c.value + phase) * 2 * math.pi) + 1) / 2;
            final scale = 0.35 + t * 0.9;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Container(
                width: 6,
                height: 30 * scale,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9999)),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Small static accent bars used as a list-item thumbnail.
class MiniWave extends StatelessWidget {
  const MiniWave({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.accent;
    const heights = <double>[10, 16, 7, 19, 12, 8, 15];
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final h in heights)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                width: 2.5,
                height: h,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Audio-player waveform that fills with the accent color up to [progress].
class PlayerWave extends StatelessWidget {
  const PlayerWave({super.key, required this.progress, this.bars = 56, this.onSeek});

  final double progress;
  final int bars;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final heights = _waveHeights(bars);
    return Expanded(
      child: GestureDetector(
        onTapDown: onSeek == null
            ? null
            : (d) {
                final width = context.size?.width ?? 1;
                onSeek!((d.localPosition.dx / width).clamp(0.0, 1.0));
              },
        child: SizedBox(
          height: 38,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < bars; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.25),
                    child: Container(
                      height: heights[i] * 32 + 4,
                      decoration: BoxDecoration(
                        color: (i / bars) <= progress ? palette.accent : palette.waveOff,
                        borderRadius: BorderRadius.circular(9999),
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
}

/// Live recording waveform driven by amplitude [levels]; greys out when paused.
class RecordWave extends StatelessWidget {
  const RecordWave({super.key, required this.levels, required this.paused});

  final List<double> levels;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 96,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final level in levels)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 5,
                height: (level.clamp(0.05, 1.0)) * 88,
                decoration: BoxDecoration(
                  color: paused ? palette.waveOff : palette.accent,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
