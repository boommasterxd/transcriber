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
/// scrollable child, used as a scroll indicator throughout the app.
class FadeEdges extends StatelessWidget {
  const FadeEdges({
    super.key,
    required this.child,
    this.topHeight = 18,
    this.bottomHeight = 30,
    this.color,
  });

  final Widget child;
  final double topHeight;
  final double bottomHeight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.bg;
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c, c.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: bottomHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.withValues(alpha: 0), c],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
