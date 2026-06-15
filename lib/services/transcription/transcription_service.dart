import '../../data/models/transcript_note.dart';

/// Result of a transcription: the full text plus optional time-stamped lines.
class TranscriptionResult {
  const TranscriptionResult({required this.text, required this.segments});

  final String text;
  final List<TranscriptLine> segments;

  bool get hasSegments => segments.isNotEmpty;
}

/// Transcribes an audio file to text. Implemented on-device (Whisper / Gemma 3n)
/// and via cloud providers.
abstract interface class TranscriptionService {
  /// [languageCode] is an ISO code or null/`auto` for auto-detection.
  Future<TranscriptionResult> transcribe(String audioPath, {String? languageCode});
}
