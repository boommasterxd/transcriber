import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/transcript_note.dart';
import '../../../widgets/surfaces.dart';

/// "Processed with" card: one row per stage (transcription + summary), each
/// showing whether it ran on-device or in the cloud, the model, and its label.
class ProcessedWithCard extends StatelessWidget {
  const ProcessedWithCard({
    super.key,
    required this.note,
    required this.strings,
  });

  final TranscriptNote note;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      radius: 20,
      child: Column(
        children: [
          _StageRow(
            label: strings.shStep1,
            isLocal: note.asrIsLocal,
            name: note.asrName,
            chip: note.asrSub,
          ),
          Divider(height: 1, color: palette.line),
          _StageRow(
            label: strings.shStep2,
            isLocal: note.summaryIsLocal,
            name: note.llmName,
            chip: note.llmSub,
          ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.isLocal,
    required this.name,
    required this.chip,
  });

  final String label;
  final bool isLocal;
  final String name;
  final String chip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          _StageBadge(isLocal: isLocal),
          const SizedBox(width: 13),
          Expanded(
            child: _StageText(label: label, name: name),
          ),
          _StageChip(label: chip),
        ],
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.isLocal});

  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isLocal ? palette.mintSoft : palette.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isLocal ? Icons.shield_outlined : Icons.cloud_outlined,
        size: 18,
        color: isLocal ? palette.mint : palette.accent,
      ),
    );
  }
}

class _StageText extends StatelessWidget {
  const _StageText({required this.label, required this.name});

  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
        Text(
          name,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: palette.muted,
        ),
      ),
    );
  }
}
