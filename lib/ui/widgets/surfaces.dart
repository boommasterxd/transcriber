import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// Rounded surface container with the design's soft shadow.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 22,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

/// Uppercase, letter-spaced section header in the faint color.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(6, 22, 6, 9),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: context.palette.faint,
        ),
      ),
    );
  }
}

/// Overlays soft top/bottom gradient fades (in the background color) over a
/// scrollable, but only on edges that can actually be scrolled toward — the top
/// fade appears once content is scrolled down, the bottom fade hides at the end.
///
/// The scrollable is created by [builder] using the provided [ScrollController]
/// so the fades stay in sync with real scroll metrics.
class FadeEdges extends StatefulWidget {
  const FadeEdges({
    super.key,
    required this.builder,
    this.topHeight = 18,
    this.bottomHeight = 30,
    this.color,
  });

  final Widget Function(BuildContext context, ScrollController controller) builder;
  final double topHeight;
  final double bottomHeight;
  final Color? color;

  @override
  State<FadeEdges> createState() => _FadeEdgesState();
}

class _FadeEdgesState extends State<FadeEdges> {
  final ScrollController _controller = ScrollController();
  bool _showTop = false;
  bool _showBottom = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.removeListener(_update);
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) return;
    final position = _controller.position;
    final showTop = position.extentBefore > 1.0;
    final showBottom = position.extentAfter > 1.0;
    if (showTop != _showTop || showBottom != _showBottom) {
      setState(() {
        _showTop = showTop;
        _showBottom = showBottom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? context.palette.bg;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _update());
        return false;
      },
      child: Stack(
        children: [
          Positioned.fill(child: widget.builder(context, _controller)),
          _Fade(visible: _showTop, height: widget.topHeight, color: c, top: true),
          _Fade(visible: _showBottom, height: widget.bottomHeight, color: c, top: false),
        ],
      ),
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({required this.visible, required this.height, required this.color, required this.top});

  final bool visible;
  final double height;
  final Color color;
  final bool top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
