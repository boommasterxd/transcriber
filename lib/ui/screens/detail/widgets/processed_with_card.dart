import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/transcript_note.dart';
import '../../../widgets/surfaces.dart';

/// "Processed with" card listing the mode and the ASR + summary models used.
class ProcessedWithCard extends StatelessWidget {
  const ProcessedWithCard({super.key, required this.note, required this.strings});

  final TranscriptNote note;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final german = strings.isDe;
    final modeLabel = note.isRemote ? strings.modeRemoteT : strings.modeLocalT;
    final modeSub = note.isRemote
        ? (note.providerId == null ? strings.modeRemoteT : _providerName(note.providerId!))
        : (german ? 'Komplett auf dem Gerät verarbeitet' : 'Processed entirely on device');

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      radius: 20,
      child: Column(
        children: [
          _Row(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: note.isRemote ? palette.accentSoft : palette.mintSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                note.isRemote ? Icons.cloud_outlined : Icons.shield_outlined,
                size: 18,
                color: note.isRemote ? palette.accent : palette.mint,
              ),
            ),
            title: modeLabel,
            subtitle: modeSub,
          ),
          Divider(height: 1, color: palette.line),
          _Row(
            leading: _modelIcon(context, Icons.graphic_eq_rounded),
            label: strings.shStep1,
            title: note.asrName,
            chip: note.asrSub,
          ),
          Divider(height: 1, color: palette.line),
          _Row(
            leading: _modelIcon(context, Icons.auto_awesome_outlined),
            label: strings.shStep2,
            title: note.llmName,
            chip: note.llmSub,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _modelIcon(BuildContext context, IconData icon) {
    final palette = context.palette;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: palette.accentSoft2, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 17, color: palette.accent),
    );
  }

  String _providerName(String id) {
    switch (id) {
      case 'anthropic':
        return 'Anthropic';
      case 'openai':
        return 'OpenAI';
      case 'google':
        return 'Google';
      case 'openrouter':
        return 'OpenRouter';
      default:
        return id;
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.leading,
    required this.title,
    this.subtitle,
    this.label,
    this.chip,
    this.isLast = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final String? label;
  final String? chip;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null)
                  Text(label!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.muted)),
                Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.ink)),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: palette.muted)),
              ],
            ),
          ),
          if (chip != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: palette.chip, borderRadius: BorderRadius.circular(9999)),
              child: Text(
                chip!,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.muted),
              ),
            ),
        ],
      ),
    );
  }
}
