import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../data/models/transcript_note.dart';
import '../../../widgets/buttons.dart';

class DetailHeaderActions {
  const DetailHeaderActions({
    required this.onBack,
    required this.onShare,
    required this.onDelete,
  });

  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onDelete;
}

class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.note,
    required this.strings,
    required this.actions,
  });

  final TranscriptNote note;
  final AppStrings strings;
  final DetailHeaderActions actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          IconCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: actions.onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
                Text(
                  '${note.speaker} · ${timeAgo(note.createdAt, t: strings)}',
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconCircleButton(
            icon: Icons.delete_outline_rounded,
            onTap: actions.onDelete,
          ),
          const SizedBox(width: 8),
          IconCircleButton(
            icon: Icons.ios_share_rounded,
            onTap: actions.onShare,
          ),
        ],
      ),
    );
  }
}
