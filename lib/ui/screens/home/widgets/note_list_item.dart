import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/transcript_note.dart';
import '../../../widgets/waveforms.dart';
import '../home_screen.dart' show noteSubtitle;

/// A single transcript row in the history list.
class NoteListItem extends StatelessWidget {
  const NoteListItem({
    super.key,
    required this.note,
    required this.strings,
    required this.onTap,
    required this.isLast,
  });

  final TranscriptNote note;
  final AppStrings strings;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        noteSubtitle(note, german: strings.isDe),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: palette.muted),
                      ),
                      const SizedBox(height: 5),
                      Row(
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
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.coralSoft,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    strings.todoLabel(note.todos.length),
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: palette.coralInk),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 18, color: palette.faint),
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
