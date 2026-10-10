import 'package:flutter/material.dart';

import '../../core/theme/app_accent.dart';
import '../../core/theme/app_palette.dart';

/// Wraps [child] so it scales down briefly while pressed, providing tactile feedback
/// without an ink ripple. Used by the primary buttons and tappable tiles.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
  });

  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Primary accent pill button with optional leading/trailing icon.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.height = 58,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final IconData? trailingIcon;
  final double height;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = outlined ? palette.accent : palette.onAccent;
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : palette.accent,
          borderRadius: BorderRadius.circular(9999),
          border: outlined
              ? Border.all(color: palette.line2, width: 1.5)
              : null,
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.36),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 19),
              const SizedBox(width: 9),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 9),
              Icon(trailingIcon, color: fg, size: 19),
            ],
          ],
        ),
      ),
    );
  }
}

/// Circular surface button (back, settings, share, close).
class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: size * 0.45, color: palette.body),
      ),
    );
  }
}

/// Selectable accent color swatches that wrap on narrow screens.
class AccentSwatches extends StatelessWidget {
  const AccentSwatches({
    super.key,
    required this.selected,
    required this.onSelected,
    this.size = 40,
  });

  final AppAccent selected;
  final ValueChanged<AppAccent> onSelected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final accent in AppAccent.values)
          GestureDetector(
            onTap: () => onSelected(accent),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: accent.color,
                shape: BoxShape.circle,
                boxShadow: accent == selected
                    ? [
                        BoxShadow(color: palette.surface, spreadRadius: 3),
                        BoxShadow(color: accent.color, spreadRadius: 5),
                      ]
                    : [BoxShadow(color: palette.shadow, blurRadius: 8)],
              ),
              child: accent == selected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
      ],
    );
  }
}
