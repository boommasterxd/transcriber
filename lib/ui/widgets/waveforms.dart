import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

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

/// Runs a purely decorative animation only while the system allows motion.
class DecorativeLoop extends StatelessWidget {
  const DecorativeLoop({
    super.key,
    required this.duration,
    required this.builder,
    this.child,
  });

  final Duration duration;
  final Widget Function(BuildContext context, double progress, Widget? child)
  builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? builder(context, 0, child)
      : _AnimatedDecoration(duration: duration, builder: builder, child: child);
}

class _AnimatedDecoration extends StatefulWidget {
  const _AnimatedDecoration({
    required this.duration,
    required this.builder,
    this.child,
  });

  final Duration duration;
  final Widget Function(BuildContext context, double progress, Widget? child)
  builder;
  final Widget? child;

  @override
  State<_AnimatedDecoration> createState() => _AnimatedDecorationState();
}

class _AnimatedDecorationState extends State<_AnimatedDecoration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) =>
        widget.builder(context, _controller.value, child),
  );
}

/// Equalizer used in onboarding and processing hero badges.
class EqWave extends StatelessWidget {
  const EqWave({super.key, this.bars = 7, this.height = 46, this.color});

  final int bars;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? context.palette.accent;
    return SizedBox(
      height: height,
      child: DecorativeLoop(
        duration: const Duration(seconds: 1),
        builder: (context, progress, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(bars, (i) {
            final phase = (i * 0.11);
            final t = (math.sin((progress + phase) * 2 * math.pi) + 1) / 2;
            final scale = 0.35 + t * 0.9;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Container(
                width: 6,
                height: 30 * scale,
                decoration: BoxDecoration(
                  color: barColor,
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
  const PlayerWave({
    super.key,
    required this.progress,
    required this.label,
    required this.semanticFormatterCallback,
    this.onSeek,
  });

  /// Throttle granularity for progress repaints. Kept comfortably finer than
  /// the rendered bars so callers can skip no-op rebuilds (see
  /// detail_audio_player) without ever missing a visible bar transition.
  static const int defaultBars = 64;

  /// Fixed bar geometry with uniform thickness that matches the app's other
  /// waveforms instead of width-dependent slivers.
  static const double _barWidth = 3.5;
  static const double _barGap = 5.0;

  final double progress;
  final String label;
  final SemanticFormatterCallback semanticFormatterCallback;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 48,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: LayoutBuilder(builder: _buildBars),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              disabledActiveTrackColor: Colors.transparent,
              disabledInactiveTrackColor: Colors.transparent,
              disabledThumbColor: palette.muted,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              value: progress,
              label: label,
              semanticFormatterCallback: semanticFormatterCallback,
              allowedInteraction: SliderInteraction.tapOnly,
              thumbColor: palette.accentDeep,
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? palette.ink.withValues(alpha: 0.55)
                    : palette.accent.withValues(alpha: 0.35),
              ),
              onChanged: onSeek,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBars(BuildContext context, BoxConstraints constraints) {
    final palette = context.palette;
    final count = ((constraints.maxWidth + _barGap) / (_barWidth + _barGap))
        .floor();
    final heights = _waveHeights(count);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: _barWidth,
            height: heights[i] * 26 + 8,
            decoration: BoxDecoration(
              color: (i / count) <= progress ? palette.accent : palette.waveOff,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
      ],
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
  const RecordWave({
    super.key,
    required this.levels,
    required this.paused,
    this.height = 96,
    this.barWidth = 5,
  });

  final List<double> levels;
  final bool paused;
  final double height;
  final double barWidth;

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
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _c.value = 1;
  }

  @override
  void didUpdateWidget(RecordWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new amplitude snapshot arrived: tween from the previous target to it.
    if (!identical(oldWidget.levels, widget.levels)) {
      _from = _to;
      _to = widget.levels;
      if (_reduceMotion) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
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
      height: widget.height,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _RecordWavePainter(
            from: _from,
            to: _to,
            progress: _c,
            color: widget.paused ? palette.waveOff : palette.accent,
            barWidth: widget.barWidth,
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
    required this.barWidth,
  }) : super(repaint: progress);

  final List<double> from;
  final List<double> to;
  final Animation<double> progress;
  final Color color;
  final double barWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final n = to.length;
    if (n == 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final slot = size.width / n;
    final t = progress.value;
    final cy = size.height / 2;
    final maxHeight =
        size.height - 8; // matches the old 88px bar over a 96px box
    for (var i = 0; i < n; i++) {
      final a = i < from.length ? from[i] : to[i];
      final level = (a + (to[i] - a) * t).clamp(0.05, 1.0);
      final h = math.max(barWidth * 2, level * maxHeight);
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
      old.barWidth != barWidth ||
      !identical(old.from, from) ||
      !identical(old.to, to);
}
