import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';

/// Shown in place of the audio player when the source audio was removed after
/// processing (auto-delete). Mirrors the design's "Audio gelöscht" notice.
class AudioDeletedNotice extends StatelessWidget {
  const AudioDeletedNotice({super.key, required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(color: palette.chip, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: palette.coralSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.delete_outline_rounded, size: 19, color: palette.coralInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.audioDelTitle,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.ink),
                ),
                Text(strings.audioDelSub, style: TextStyle(fontSize: 12, color: palette.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.info_outline_rounded, size: 16, color: palette.faint),
        ],
      ),
    );
  }
}
