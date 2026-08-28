import '../../data/models/transcription_result.dart';

export '../../data/models/transcription_result.dart';

/// Transcribes an audio file to text. Implemented on-device (Whisper / Gemma 3n)
/// and via cloud providers.
abstract interface class TranscriptionService {
  /// [languageCode] is an ISO code or null/`auto` for auto-detection.
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
  });
}
