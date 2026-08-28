import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/transcript_note.dart';
import '../../../widgets/todo_tile.dart';

class NoteSectionLabel extends StatelessWidget {
  const NoteSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
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
    this.bottomPadding = 15,
    this.fontSize = 14.5,
  });

  final List<String> points;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final point in points)
          _NoteTextRow(
            leading: Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
            ),
            text: point,
            style: style,
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
    return Row(
      children: [
        NoteSectionLabel(label),
        const SizedBox(width: 8),
        Container(
          constraints: const BoxConstraints(minWidth: 20),
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: palette.coral,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Center(
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class EditableNoteTodos extends StatelessWidget {
  const EditableNoteTodos.phone({
    super.key,
    required this.todos,
    required this.strings,
    required this.onToggle,
  }) : bottomPadding = 10;

  const EditableNoteTodos.tablet({
    super.key,
    required this.todos,
    required this.strings,
    required this.onToggle,
  }) : bottomPadding = 9;

  final List<TodoItem> todos;
  final AppStrings strings;
  final ValueChanged<int> onToggle;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteTodoHeader(count: todos.length, label: strings.shActions),
        const SizedBox(height: 12),
        for (var index = 0; index < todos.length; index++)
          Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: TodoTile(
              text: todos[index].text,
              done: todos[index].done,
              onToggle: () => onToggle(index),
            ),
          ),
      ],
    );
  }
}

class TranscriptRows extends StatelessWidget {
  const TranscriptRows({
    super.key,
    required this.lines,
    this.bottomPadding = 15,
    this.fontSize = 14.5,
  });

  final List<TranscriptLine> lines;
  final double bottomPadding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Text(
              line.text,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.5,
                color: palette.body,
              ),
            ),
          ),
      ],
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
