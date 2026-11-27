import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../data/models/transcript_note.dart';

class AiProvenanceLabel extends StatelessWidget {
  const AiProvenanceLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: context.palette.body,
    ),
  );
}

class AiSummaryItemsProvenance extends StatelessWidget {
  const AiSummaryItemsProvenance({
    super.key,
    required this.note,
    required this.strings,
    this.padding = EdgeInsets.zero,
  });

  final TranscriptNote note;
  final AppStrings strings;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!note.hasAiGeneratedSummary) return const SizedBox.shrink();
    final label = switch ((note.points.isNotEmpty, note.todos.isNotEmpty)) {
      (true, true) => strings.aiGeneratedPointsAndActions,
      (true, false) => strings.aiGeneratedPoints,
      (false, true) => strings.aiGeneratedActions,
      (false, false) => null,
    };
    if (label == null) return const SizedBox.shrink();
    return Padding(padding: padding, child: AiProvenanceLabel(label));
  }
}
