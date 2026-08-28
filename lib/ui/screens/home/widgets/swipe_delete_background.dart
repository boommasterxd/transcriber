import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/transcript_note.dart';
import '../../../widgets/note_actions.dart';

enum SwipeDeleteStyle { phone, tablet }

class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key, this.style = SwipeDeleteStyle.phone});

  final SwipeDeleteStyle style;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tablet = style == SwipeDeleteStyle.tablet;
    return Container(
      margin: tablet ? const EdgeInsets.only(bottom: 3) : null,
      padding: EdgeInsets.symmetric(horizontal: tablet ? 18 : 22),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: palette.coral,
        borderRadius: tablet ? BorderRadius.circular(16) : null,
      ),
      child: Icon(
        Icons.delete_outline_rounded,
        color: Colors.white,
        size: tablet ? 22 : 24,
      ),
    );
  }
}

class DismissibleHistoryNote extends ConsumerWidget {
  const DismissibleHistoryNote({
    super.key,
    required this.note,
    required this.strings,
    required this.child,
    this.style = SwipeDeleteStyle.phone,
  });

  final TranscriptNote note;
  final AppStrings strings;
  final Widget child;
  final SwipeDeleteStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => deleteNoteWithUndo(ref, note, strings),
      background: SwipeDeleteBackground(style: style),
      child: child,
    );
  }
}
