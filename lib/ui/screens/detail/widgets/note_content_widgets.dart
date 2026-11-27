import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/transcript_note.dart';
import '../../../widgets/todo_tile.dart';

class NoteSectionLabel extends StatelessWidget {
  const NoteSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      header: true,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: context.palette.ink,
        ),
      ),
    );
  }
}

class NoteKeyPoints extends StatelessWidget {
  const NoteKeyPoints({
    super.key,
    required this.points,
    required this.label,
    this.bottomPadding = 15,
    this.fontSize = 14.5,
  });

  final List<String> points;
  final String label;
  final double bottomPadding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = _NoteRowStyle(
      bottomPadding: bottomPadding,
      fontSize: fontSize,
      gap: 11,
      lineHeight: 1.45,
    );
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: NoteSectionLabel(label)),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverList.builder(
          itemCount: points.length,
          itemBuilder: (context, index) => _NoteTextRow(
            leading: Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
            ),
            text: points[index],
            style: style,
          ),
        ),
      ],
    );
  }
}

class NoteTodoHeader extends StatelessWidget {
  const NoteTodoHeader({super.key, required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        NoteSectionLabel(label),
        Container(
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: palette.coralSoft,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: palette.coralInk,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NoteTodos extends StatelessWidget {
  const NoteTodos.phone({
    super.key,
    required this.todos,
    required this.strings,
    required this.onToggle,
  }) : bottomPadding = 10;

  const NoteTodos.tablet({
    super.key,
    required this.todos,
    required this.strings,
    required this.onToggle,
  }) : bottomPadding = 9;

  const NoteTodos.preview({
    super.key,
    required this.todos,
    required this.strings,
  }) : onToggle = null,
       bottomPadding = 12;

  final List<TodoItem> todos;
  final AppStrings strings;
  final ValueChanged<int>? onToggle;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: NoteTodoHeader(count: todos.length, label: strings.shActions),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverList.builder(itemCount: todos.length, itemBuilder: _buildTodo),
      ],
    );
  }

  Widget _buildTodo(BuildContext context, int index) {
    final todo = todos[index];
    final toggle = onToggle;
    if (toggle == null) {
      return _NoteTextRow(
        leading: Icon(
          Icons.check_circle_outline_rounded,
          size: 18,
          color: context.palette.coral,
        ),
        text: todo.text,
        style: const _NoteRowStyle(
          bottomPadding: 12,
          fontSize: 14.5,
          gap: 11,
          lineHeight: 1.45,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: TodoTile(
        text: todo.text,
        done: todo.done,
        onToggle: () => toggle(index),
      ),
    );
  }
}

class _NoteTextRow extends StatelessWidget {
  const _NoteTextRow({
    required this.leading,
    required this.text,
    required this.style,
  });

  final Widget leading;
  final String text;
  final _NoteRowStyle style;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: style.bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          SizedBox(width: style.gap),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: style.fontSize,
                height: style.lineHeight,
                color: palette.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRowStyle {
  const _NoteRowStyle({
    required this.bottomPadding,
    required this.fontSize,
    required this.gap,
    required this.lineHeight,
  });

  final double bottomPadding;
  final double fontSize;
  final double gap;
  final double lineHeight;
}
