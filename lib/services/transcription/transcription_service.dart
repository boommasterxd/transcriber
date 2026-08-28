import '../../data/models/transcription_result.dart';

export '../../data/models/transcription_result.dart';

/// Transcribes an audio file to text through a cloud provider.
abstract interface class TranscriptionService {
  /// [languageCode] is an ISO code or null/`auto` for auto-detection.
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
  });
}
