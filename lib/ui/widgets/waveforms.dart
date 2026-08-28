import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// Deterministic pseudo-waveform heights (0.2..1.0) used by the players.
/// Cached per bar count: the values never change, and [PlayerWave] rebuilds on
/// every playback tick, so recomputing the sines each frame was pure waste.
final Map<int, List<double>> _waveHeightsCache = {};

List<double> _waveHeights(int count) => _waveHeightsCache.putIfAbsent(
  count,
  () => List.generate(count, (i) {
    final a =
        (math.sin(i * 0.6) +
                0.55 * math.sin(i * 0.21) +
                0.3 * math.sin(i * 1.3))
            .abs();
    return 0.2 + 0.8 * math.min(1.0, a / 1.6);
  }),
);

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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

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
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(9999),
                ),
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
///
/// Bars have a fixed, uniform thickness (not [Expanded]) so the waveform reads
/// the same on any width: a handful of solid bars rather than dozens of thin
/// hairlines. The bar count is derived from the available width so the density
/// stays consistent across the phone dialog and the wider tablet pane.
class PlayerWave extends StatelessWidget {
  const PlayerWave({super.key, required this.progress, this.onSeek});

  /// Throttle granularity for progress repaints. Kept comfortably finer than
  /// the rendered bars so callers can skip no-op rebuilds (see
  /// detail_audio_player) without ever missing a visible bar transition.
  static const int defaultBars = 64;

  /// Fixed bar geometry with uniform thickness that matches the app's other
  /// waveforms instead of width-dependent slivers.
  static const double _barWidth = 3.5;
  static const double _barGap = 5.0;

  final double progress;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // How many fixed-width bars fit, evenly spaced by at least _barGap.
          final count = math.max(
            1,
            ((width + _barGap) / (_barWidth + _barGap)).floor(),
          );
          final heights = _waveHeights(count);
          return GestureDetector(
            onTapDown: onSeek == null
                ? null
                : (d) => onSeek!((d.localPosition.dx / width).clamp(0.0, 1.0)),
            child: SizedBox(
              height: 38,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < count; i++)
                    Container(
                      width: _barWidth,
                      height: heights[i] * 26 + 8,
                      decoration: BoxDecoration(
                        color: (i / count) <= progress
                            ? palette.accent
                            : palette.waveOff,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Live recording waveform driven by amplitude [levels]; greys out when paused.
///
/// Painted with a single [CustomPainter] and one animation controller instead
/// of one [AnimatedContainer] per bar. The old approach spun up ~40 implicit
/// animation controllers that all re-targeted on every 120 ms amplitude tick,
/// a steady source of dropped frames while recording. Here one controller tweens
/// every bar between the previous and current amplitude snapshot, and an
/// enclosing [RepaintBoundary] keeps the repaints off the rest of the screen.
class RecordWave extends StatefulWidget {
  const RecordWave({super.key, required this.levels, required this.paused});

  final List<double> levels;
  final bool paused;

  @override
  State<RecordWave> createState() => _RecordWaveState();
}

class _RecordWaveState extends State<RecordWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  )..value = 1;

  late List<double> _from = widget.levels;
  late List<double> _to = widget.levels;

  @override
  void didUpdateWidget(RecordWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new amplitude snapshot arrived: tween from the previous target to it.
    if (!identical(oldWidget.levels, widget.levels)) {
      _from = _to;
      _to = widget.levels;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 96,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _RecordWavePainter(
            from: _from,
            to: _to,
            progress: _c,
            color: widget.paused ? palette.waveOff : palette.accent,
          ),
        ),
      ),
    );
  }
}

class _RecordWavePainter extends CustomPainter {
  _RecordWavePainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.color,
  }) : super(repaint: progress);

  final List<double> from;
  final List<double> to;
  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final n = to.length;
    if (n == 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const barWidth = 5.0;
    final slot = size.width / n;
    final t = progress.value;
    final cy = size.height / 2;
    final maxHeight =
        size.height - 8; // matches the old 88px bar over a 96px box
    for (var i = 0; i < n; i++) {
      final a = i < from.length ? from[i] : to[i];
      final level = (a + (to[i] - a) * t).clamp(0.05, 1.0);
      final h = level * maxHeight;
      final cx = slot * i + slot / 2;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: barWidth,
        height: h,
      );
      canvas.drawRRect(
        RRect.fromRectXY(rect, barWidth / 2, barWidth / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RecordWavePainter old) =>
      old.color != color ||
      !identical(old.from, from) ||
      !identical(old.to, to);
}
