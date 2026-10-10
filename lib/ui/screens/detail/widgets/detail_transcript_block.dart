import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/transcript_note.dart';
import 'note_content_widgets.dart';
import 'note_summary_metadata_widgets.dart';

class DetailTranscriptActions {
  const DetailTranscriptActions({required this.onCopy, this.onShare});

  final VoidCallback onCopy;
  final VoidCallback? onShare;
}

class DetailTranscriptStyle {
  const DetailTranscriptStyle({
    this.rowBottomPadding = 15,
    this.rowFontSize = 14.5,
  });

  final double rowBottomPadding;
  final double rowFontSize;
}

class DetailTranscriptBlock extends StatelessWidget {
  const DetailTranscriptBlock({
    super.key,
    required this.note,
    required this.strings,
    required this.copied,
    required this.actions,
    this.style = const DetailTranscriptStyle(),
  });

  final TranscriptNote note;
  final AppStrings strings;
  final bool copied;
  final DetailTranscriptActions actions;
  final DetailTranscriptStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            NoteSectionLabel(strings.shTranscript),
            Row(
              children: [
                NotePillChip.action(
                  icon: copied ? Icons.check_rounded : Icons.copy_rounded,
                  label: copied ? strings.shCopied : strings.shCopy,
                  highlight: copied,
                  onTap: actions.onCopy,
                ),
                if (actions.onShare != null) ...[
                  const SizedBox(width: 8),
                  NotePillChip.action(
                    icon: Icons.ios_share_rounded,
                    label: strings.shShare,
                    onTap: actions.onShare!,
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        TranscriptRows(
          lines: note.transcript,
          bottomPadding: style.rowBottomPadding,
          fontSize: style.rowFontSize,
        ),
      ],
    );
  }
}

class DetailTranscriptToggle extends StatelessWidget {
  const DetailTranscriptToggle.phone({
    super.key,
    required this.strings,
    required this.isOpen,
    required this.onTap,
  }) : height = 52,
       showChevron = true;

  const DetailTranscriptToggle.tablet({
    super.key,
    required this.strings,
    required this.isOpen,
    required this.onTap,
  }) : height = 50,
       showChevron = false;

  final AppStrings strings;
  final bool isOpen;
  final VoidCallback onTap;
  final double height;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      expanded: isOpen,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.accent,
            side: BorderSide(color: palette.line2, width: 1.5),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.subject_rounded, size: 19),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(isOpen ? strings.shHide : strings.shShow)),
              if (showChevron) ...[
                const SizedBox(width: 9),
                Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 19,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
