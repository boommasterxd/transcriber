import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';

/// Shared recording actions used by the full-screen recorder and live keyboard.
class RecordControls extends StatelessWidget {
  const RecordControls({
    super.key,
    required this.paused,
    required this.strings,
    required this.actions,
    this.compact = false,
  });

  final bool paused;
  final AppStrings strings;
  final RecordingActions actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dimensions = compact
        ? const _ControlDimensions.compact()
        : const _ControlDimensions.regular();
    return Padding(
      padding: dimensions.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _RecordAction(
              icon: Icons.delete_outline_rounded,
              label: strings.recCancel,
              color: context.palette.coralInk,
              onTap: actions.cancel,
              dimensions: dimensions,
            ),
          ),
          Expanded(
            child: _RecordStopAction(
              label: strings.recStopShort,
              onTap: actions.stop,
              dimensions: dimensions,
            ),
          ),
          Expanded(
            child: _RecordAction(
              icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              label: paused ? strings.recResume : strings.recPause,
              color: context.palette.body,
              onTap: actions.togglePause,
              dimensions: dimensions,
            ),
          ),
        ],
      ),
    );
  }
}

/// A null callback disables the corresponding recording action.
class RecordingActions {
  const RecordingActions({this.cancel, this.stop, this.togglePause});

  final VoidCallback? cancel;
  final VoidCallback? stop;
  final VoidCallback? togglePause;
}

/// Microphone start action matching the central stop control.
class RecordStartControl extends StatelessWidget {
  const RecordStartControl({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dimensions = compact
        ? const _ControlDimensions.compact()
        : const _ControlDimensions.regular();
    return Center(
      child: _CircularAction(
        label: label,
        onTap: onTap,
        dimensions: dimensions,
        color: context.palette.accent,
        shadow: true,
        child: Icon(
          Icons.mic_rounded,
          color: Colors.white,
          size: dimensions.stopIconSize,
        ),
      ),
    );
  }
}

class _RecordStopAction extends StatelessWidget {
  const _RecordStopAction({
    required this.label,
    required this.onTap,
    required this.dimensions,
  });

  final String label;
  final VoidCallback? onTap;
  final _ControlDimensions dimensions;

  @override
  Widget build(BuildContext context) => Center(
    child: _CircularAction(
      label: label,
      onTap: onTap,
      dimensions: dimensions,
      color: context.palette.accent,
      shadow: true,
      child: Container(
        width: dimensions.stopIconSize,
        height: dimensions.stopIconSize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dimensions.stopIconSize / 4),
        ),
      ),
    ),
  );
}

class _RecordAction extends StatelessWidget {
  const _RecordAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.dimensions,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final _ControlDimensions dimensions;

  @override
  Widget build(BuildContext context) => Center(
    child: _CircularAction(
      label: label,
      onTap: onTap,
      dimensions: dimensions,
      color: context.palette.chip,
      child: Icon(icon, color: color, size: dimensions.sideIconSize),
    ),
  );
}

class _CircularAction extends StatelessWidget {
  const _CircularAction({
    required this.label,
    required this.onTap,
    required this.dimensions,
    required this.color,
    required this.child,
    this.shadow = false,
  });

  final String label;
  final VoidCallback? onTap;
  final _ControlDimensions dimensions;
  double get size => shadow ? dimensions.stopSize : dimensions.sideSize;
  double get labelSize => dimensions.labelSize;
  final Color color;
  final Widget child;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.42,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onTap,
            radius: size / 2 + 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: shadow && enabled
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: size * 0.4,
                              offset: Offset(0, size * 0.16),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(child: child),
                ),
                SizedBox(height: size >= 70 ? 8 : 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: labelSize,
                    fontWeight: FontWeight.w700,
                    color: shadow ? color : context.palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlDimensions {
  const _ControlDimensions.regular()
    : padding = const EdgeInsets.fromLTRB(36, 16, 36, 32),
      sideSize = 58,
      stopSize = 80,
      sideIconSize = 24,
      stopIconSize = 26,
      labelSize = 12;

  const _ControlDimensions.compact()
    : padding = const EdgeInsets.symmetric(horizontal: 18),
      sideSize = 48,
      stopSize = 60,
      sideIconSize = 22,
      stopIconSize = 21,
      labelSize = 11;

  final EdgeInsets padding;
  final double sideSize;
  final double stopSize;
  final double sideIconSize;
  final double stopIconSize;
  final double labelSize;
}
