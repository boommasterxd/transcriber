import 'transcript_note.dart';

/// Result of a transcription: the full text plus optional time-stamped lines.
class TranscriptionResult {
  const TranscriptionResult({required this.text, required this.segments});

  final String text;
  final List<TranscriptLine> segments;

  bool get hasSegments => segments.isNotEmpty;
}
