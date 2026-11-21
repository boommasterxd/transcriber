import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_palette.dart';

/// Checkable action-item tile (coral background, mint check when done).
class TodoTile extends StatefulWidget {
  const TodoTile({
    super.key,
    required this.text,
    required this.done,
    required this.onToggle,
  });

  final String text;
  final bool done;
  final VoidCallback onToggle;

  @override
  State<TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<TodoTile>
    with AutomaticKeepAliveClientMixin {
  bool _focused = false;

  @override
  bool get wantKeepAlive => _focused;

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = context.palette;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(16);
    return Semantics(
      container: true,
      checked: widget.done,
      enabled: true,
      label: widget.text,
      onTap: widget.onToggle,
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: widget.done ? palette.mintSoft : palette.coralSoft,
          borderRadius: radius,
        ),
        foregroundDecoration: BoxDecoration(
          border: _focused ? Border.all(color: palette.ink, width: 2) : null,
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onToggle,
            onFocusChange: _onFocusChange,
            borderRadius: radius,
            excludeFromSemantics: true,
            child: ExcludeSemantics(child: _content(context, reduceMotion)),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, bool reduceMotion) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _TodoMark(done: widget.done),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: palette.body,
                decoration: widget.done ? TextDecoration.lineThrough : null,
                decorationColor: palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoMark extends StatelessWidget {
  _TodoMark({required this.done}) : super(key: ValueKey(done));

  final bool done;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: done ? palette.mintInk : null,
        borderRadius: BorderRadius.circular(8),
        border: done ? null : Border.all(color: palette.coralInk, width: 2),
      ),
      child: done ? Icon(Icons.check, color: palette.mintSoft, size: 13) : null,
    );
  }
}
