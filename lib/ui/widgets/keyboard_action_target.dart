import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';

typedef KeyboardAction = ({
  String label,
  VoidCallback onActivate,
  BorderRadius focusBorderRadius,
  bool? selected,
  bool inMutuallyExclusiveGroup,
});

/// Adds keyboard activation, semantics and a visible focus indicator to a hit
/// target.
class KeyboardActionTarget extends StatefulWidget {
  const KeyboardActionTarget({
    super.key,
    required this.child,
    required this.action,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
  });

  final Widget child;
  final KeyboardAction action;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;

  @override
  State<KeyboardActionTarget> createState() => _KeyboardActionTargetState();
}

class _KeyboardActionTargetState extends State<KeyboardActionTarget> {
  bool _showFocusHighlight = false;

  void _setFocusHighlight(bool value) {
    if (_showFocusHighlight != value) {
      setState(() => _showFocusHighlight = value);
    }
  }

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    onShowFocusHighlight: _setFocusHighlight,
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    },
    actions: <Type, Action<Intent>>{
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.action.onActivate();
          return null;
        },
      ),
    },
    child: _semantics(context),
  );

  Widget _semantics(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: widget.action.label,
    selected: widget.action.selected,
    inMutuallyExclusiveGroup: widget.action.inMutuallyExclusiveGroup,
    onTap: widget.action.onActivate,
    child: ExcludeSemantics(child: _gesture(context)),
  );

  Widget _gesture(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.action.onActivate,
    onTapDown: widget.onTapDown,
    onTapUp: widget.onTapUp,
    onTapCancel: widget.onTapCancel,
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: _focusDecoration(context),
      child: widget.child,
    ),
  );

  BoxDecoration _focusDecoration(BuildContext context) => BoxDecoration(
    borderRadius: widget.action.focusBorderRadius,
    boxShadow: _showFocusHighlight
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
