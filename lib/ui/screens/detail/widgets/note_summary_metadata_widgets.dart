import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../data/models/transcript_note.dart';

class NoteSummaryCard extends StatelessWidget {
  const NoteSummaryCard({
    super.key,
    required this.gist,
    required this.label,
    this.textSize = 15.5,
  });

  final String gist;
  final String label;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accentSoft2, palette.accentSoft],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 17, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: palette.accentDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            gist,
            style: TextStyle(
              fontSize: textSize,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: palette.body,
            ),
          ),
        ],
      ),
    );
  }
}

class NoteMetadataChips extends StatelessWidget {
  const NoteMetadataChips({
    super.key,
    required this.note,
    required this.strings,
  });

  final TranscriptNote note;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        NotePillChip(
          icon: Icons.schedule_rounded,
          label: formatDuration(note.durationSec),
        ),
        NotePillChip(
          icon: Icons.person_outline_rounded,
          label: strings.mSpkTemplate.replaceAll('{n}', '1'),
        ),
        NotePillChip(icon: Icons.language_rounded, label: strings.autoLang),
      ],
    );
  }
}

class NotePillChip extends StatelessWidget {
  const NotePillChip({super.key, required this.icon, required this.label})
    : onTap = null,
      highlight = false,
      _horizontalPadding = 12,
      _fontWeight = FontWeight.w600;

  const NotePillChip.action({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  }) : _horizontalPadding = 13,
       _fontWeight = FontWeight.w700;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;
  final double _horizontalPadding;
  final FontWeight _fontWeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = highlight ? palette.mint : palette.body;
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: onTap == null ? palette.muted : color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: _fontWeight,
              color: color,
            ),
          ),
        ],
      ),
    );
    return onTap == null
        ? content
        : GestureDetector(onTap: onTap, child: content);
  }
}
