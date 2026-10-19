import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/note_history.dart';
import '../../../widgets/waveforms.dart';
import '../note_presentation.dart';
import 'note_badges.dart';

/// A single transcript row in the history list.
class NoteListItem extends StatelessWidget {
  const NoteListItem({
    super.key,
    required this.note,
    required this.strings,
    required this.onTap,
    required this.isLast,
  });

  final NoteHistoryEntry note;
  final AppStrings strings;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(child: MiniWave()),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: _NoteText(note: note, strings: strings),
                ),
                const SizedBox(width: 8),
                TodoCountBadge(count: note.todoCount, strings: strings),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: palette.faint,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 75),
            child: Divider(height: 1, thickness: 1, color: palette.line),
          ),
      ],
    );
  }
}

class _NoteText extends StatelessWidget {
  const _NoteText({required this.note, required this.strings});

  final NoteHistoryEntry note;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          noteSubtitle(note, strings: strings),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: palette.muted),
        ),
        const SizedBox(height: 5),
        NoteModelBadge(note: note),
      ],
    );
  }
}
