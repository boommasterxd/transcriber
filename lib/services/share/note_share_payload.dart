import 'dart:convert';

import '../../core/l10n/app_strings.dart';
import '../../data/models/transcript_note.dart';

const _generatedSourceType =
    'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia';

String noteShareText(TranscriptNote note, AppStrings strings) {
  final generatedTitle = note.titleIsAiGenerated == true;
  final hasSummary = note.summaryError == null && note.gist.trim().isNotEmpty;
  final generatedSummary = hasSummary && note.hasAiGeneratedSummary;
  final sections = <String>[];
  if (generatedTitle || generatedSummary) {
    final metadata = jsonEncode({
      'version': 2,
      if (generatedTitle) 'title': {'digitalSourceType': _generatedSourceType},
      if (generatedSummary)
        'summary': {'digitalSourceType': _generatedSourceType},
    });
    sections.add('Transcriber-Provenance: $metadata');
  }
  sections.add(
    generatedTitle ? '${strings.aiGeneratedTitle}\n${note.title}' : note.title,
  );
  if (hasSummary) {
    final label = generatedSummary
        ? strings.aiGeneratedSummary
        : strings.unknownSummaryOrigin;
    sections.add('$label\n${note.gist}');
  }
  sections.add(note.fullTranscriptText);
  return sections.join('\n\n');
}
