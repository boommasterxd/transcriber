import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_accent.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'keyboard_action_target.dart';

/// Wraps [child] so it scales down briefly while pressed, providing tactile feedback
/// without an ink ripple. Used by the primary buttons and tappable tiles.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.action,
    this.pressedScale = 0.96,
    this.liveRegion = false,
  });

  final Widget child;
  final KeyboardAction action;
  final double pressedScale;
  final bool liveRegion;

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
    return KeyboardActionTarget(
      action: widget.action,
      liveRegion: widget.liveRegion,
      pressFeedback: (
        onDown: (_) => _set(true),
        onUp: (_) => _set(false),
        onCancel: () => _set(false),
      ),
      child: AnimatedScale(
        scale: _pressed && widget.action.onActivate != null
            ? widget.pressedScale
            : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
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
  }) : outlined = false,
       liveRegion = false;

  const PillButton.outlined({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.height = 58,
  }) : outlined = true,
       liveRegion = false;

  /// Announces label changes while an action is in progress.
  const PillButton.status({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.height = 58,
  }) : trailingIcon = null,
       outlined = false,
       liveRegion = true;

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;
  final double height;
  final bool outlined;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onTap != null;
    final fg = enabled
        ? outlined
              ? palette.accentDeep
              : palette.onAccent
        : palette.muted;
    return PressableScale(
      liveRegion: liveRegion,
      action: (
        label: label,
        onActivate: onTap,
        focusBorderRadius: BorderRadius.circular(20),
        selected: null,
        inMutuallyExclusiveGroup: false,
      ),
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? outlined
                    ? Colors.transparent
                    : palette.accent
              : palette.chip,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: outlined
              ? Border.all(color: palette.line2, width: 1.5)
              : null,
          boxShadow: outlined || !enabled
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
                textAlign: TextAlign.center,
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
    this.semanticLabel,
    required this.onTap,
    this.size = 42,
  });

  final IconData icon;
  final String? semanticLabel;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strings = AppStrings.of(
      Localizations.localeOf(context).languageCode == 'de'
          ? AppLanguage.de
          : AppLanguage.en,
    );
    final label =
        semanticLabel ??
        switch (icon) {
          Icons.close_rounded => strings.actionClose,
          Icons.arrow_back_ios_new_rounded => strings.actionBack,
          Icons.delete_outline_rounded => strings.actionDelete,
          Icons.ios_share_rounded => strings.actionShare,
          Icons.settings_outlined => strings.setTitle,
          _ => strings.actionClose,
        };
    return PressableScale(
      action: (
        label: label,
        onActivate: onTap,
        focusBorderRadius: BorderRadius.circular(size),
        selected: null,
        inMutuallyExclusiveGroup: false,
      ),
      pressedScale: 0.9,
      child: _CircleTouchTarget(
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
    required this.strings,
    this.size = 40,
  });

  final AppAccent selected;
  final ValueChanged<AppAccent> onSelected;
  final AppStrings strings;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: strings.accentC,
      container: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final accent in AppAccent.values)
            PressableScale(
              action: (
                label: strings.accentName(accent),
                onActivate: () => onSelected(accent),
                focusBorderRadius: BorderRadius.circular(size),
                selected: accent == selected,
                inMutuallyExclusiveGroup: true,
              ),
              child: _CircleTouchTarget(
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
                      ? Icon(Icons.check, color: palette.onAccent, size: 16)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleTouchTarget extends StatelessWidget {
  const _CircleTouchTarget({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(
      minWidth: kMinInteractiveDimension,
      minHeight: kMinInteractiveDimension,
    ),
    child: Center(widthFactor: 1, heightFactor: 1, child: child),
  );
}
