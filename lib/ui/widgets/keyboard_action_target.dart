import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';

typedef KeyboardAction = ({
  String label,
  VoidCallback? onActivate,
  BorderRadius focusBorderRadius,
  bool? selected,
  bool inMutuallyExclusiveGroup,
});

typedef PressFeedback = ({
  GestureTapDownCallback onDown,
  GestureTapUpCallback onUp,
  GestureTapCancelCallback onCancel,
});

/// Adds keyboard activation, semantics and a visible focus indicator to a hit
/// target.
class KeyboardActionTarget extends StatefulWidget {
  const KeyboardActionTarget({
    super.key,
    required this.child,
    required this.action,
    this.liveRegion = false,
    this.pressFeedback,
  });

  final Widget child;
  final KeyboardAction action;
  final bool liveRegion;
  final PressFeedback? pressFeedback;

  @override
  State<KeyboardActionTarget> createState() => _KeyboardActionTargetState();
}

class _KeyboardActionTargetState extends State<KeyboardActionTarget> {
  bool _showFocusHighlight = false;
  bool get _enabled => widget.action.onActivate != null;

  void _setFocusHighlight(bool value) {
    if (_showFocusHighlight != value) {
      setState(() => _showFocusHighlight = value);
    }
  }

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    enabled: _enabled,
    onShowFocusHighlight: _setFocusHighlight,
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    },
    actions: <Type, Action<Intent>>{
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.action.onActivate?.call();
          return null;
        },
      ),
    },
    child: _semantics(context),
  );

  Widget _semantics(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: _enabled,
    liveRegion: widget.liveRegion,
    label: widget.action.label,
    selected: widget.action.selected,
    inMutuallyExclusiveGroup: widget.action.inMutuallyExclusiveGroup,
    onTap: widget.action.onActivate,
    child: ExcludeSemantics(child: _gesture(context)),
  );

  Widget _gesture(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.action.onActivate,
    onTapDown: _enabled ? widget.pressFeedback?.onDown : null,
    onTapUp: _enabled ? widget.pressFeedback?.onUp : null,
    onTapCancel: _enabled ? widget.pressFeedback?.onCancel : null,
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: _focusDecoration(context),
      child: widget.child,
    ),
  );

  BoxDecoration _focusDecoration(BuildContext context) => BoxDecoration(
    borderRadius: widget.action.focusBorderRadius,
    boxShadow: _enabled && _showFocusHighlight
        ? [
            for (
              var index = 0;
              index < context.palette.focusIndicatorColors.length;
              index++
            )
              BoxShadow(
                color: context.palette.focusIndicatorColors[index],
                spreadRadius: (index + 1) * 2,
                blurRadius: 0,
              ),
          ]
        : null,
  );
}
