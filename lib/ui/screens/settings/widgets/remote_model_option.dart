import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../services/remote/remote_api_client.dart';

/// A native single-choice control with the rounded checkmark used by to-dos.
class RemoteModelOption extends StatefulWidget {
  const RemoteModelOption({super.key, required this.model});

  final RemoteModelInfo model;

  @override
  State<RemoteModelOption> createState() => _RemoteModelOptionState();
}

class _RemoteModelOptionState extends State<RemoteModelOption> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: RawRadio<String>(
      value: widget.model.id,
      mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
      toggleable: false,
      focusNode: _focusNode,
      autofocus: false,
      groupRegistry: RadioGroup.maybeOf<String>(context),
      enabled: true,
      builder: (context, state) {
        final palette = context.palette;
        final selected = state.value ?? false;
        final highlighted =
            state.states.contains(WidgetState.focused) ||
            state.states.contains(WidgetState.hovered);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            color: highlighted ? palette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: state.states.contains(WidgetState.focused)
                  ? palette.accent
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? palette.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: selected
                      ? null
                      : Border.all(color: palette.accent, width: 2),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 13)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.model.display,
                      style: TextStyle(fontSize: 15, color: palette.ink),
                    ),
                    if (widget.model.display != widget.model.id) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.model.id,
                        style: TextStyle(fontSize: 12.5, color: palette.body),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
