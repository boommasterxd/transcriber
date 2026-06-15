import '../transcription/transcription_service.dart';

/// A cloud provider client. Each provider implements chat (for summaries) and,
/// where supported, audio transcription.
abstract interface class RemoteApiClient {
  /// Single-turn completion. Returns the raw text response.
  Future<String> chat({
    required String system,
    required String user,
    required String modelId,
  });

  /// Transcribes an audio file. Throws if the provider has no native ASR.
  Future<TranscriptionResult> transcribe(String audioPath, {String? languageCode});

  /// Whether [transcribe] is supported by this provider.
  bool get supportsAudioTranscription;

  /// Human-readable label of the cloud ASR model (for note metadata).
  String get asrLabel;
}
