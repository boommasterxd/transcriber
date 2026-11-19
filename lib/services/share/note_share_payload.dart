import 'dart:convert';

import '../../core/l10n/app_strings.dart';
import '../../data/models/transcript_note.dart';

const _generatedSourceType =
    'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia';

String noteShareText(TranscriptNote note, AppStrings strings) {
  final sections = <String>[];
  if (note.hasAiGeneratedSummary) {
    final metadata = jsonEncode({
      'version': 1,
      'summary': {'digitalSourceType': _generatedSourceType},
    });
    sections.add('Transcriber-Provenance: $metadata');
  }
  sections.add(note.title);
  if (note.summaryError == null && note.gist.trim().isNotEmpty) {
    final label = note.hasAiGeneratedSummary
        ? strings.aiGeneratedSummary
        : strings.unknownSummaryOrigin;
    sections.add('$label\n${note.gist}');
  }
  sections.add(note.fullTranscriptText);
  return sections.join('\n\n');
}
