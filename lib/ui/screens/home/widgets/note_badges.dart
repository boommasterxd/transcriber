import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/note_history.dart';

class NoteModelBadge extends StatelessWidget {
  const NoteModelBadge({super.key, required this.note});

  final NoteHistoryEntry note;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: note.isRemote ? palette.accent : palette.mint,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            note.modelShort,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
        ),
      ],
    );
  }
}

enum TodoBadgeDensity { regular, compact }

class TodoCountBadge extends StatelessWidget {
  const TodoCountBadge({
    super.key,
    required this.count,
    required this.strings,
    this.density = TodoBadgeDensity.regular,
  });

  final int count;
  final AppStrings strings;
  final TodoBadgeDensity density;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final compact = density == TodoBadgeDensity.compact;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: palette.coralSoft,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        strings.todoLabel(count),
        style: TextStyle(
          fontSize: compact ? 11 : 11.5,
          fontWeight: FontWeight.w700,
          color: palette.coralInk,
        ),
      ),
    );
  }
}
