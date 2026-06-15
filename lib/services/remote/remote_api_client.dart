import '../transcription/transcription_service.dart';

/// A model offered by a cloud provider, fetched live from its API.
class RemoteModelInfo {
  const RemoteModelInfo({required this.id, this.label});

  final String id;
  final String? label;

  String get display => (label == null || label!.isEmpty) ? id : label!;
}

/// A cloud provider client. Each provider implements chat (for summaries) and,
/// where supported, audio transcription, plus a live model listing.
abstract interface class RemoteApiClient {
  /// Single-turn completion. Returns the raw text response.
  Future<String> chat({
    required String system,
    required String user,
    required String modelId,
  });

  /// Transcribes an audio file with [model]. Throws if the provider has no ASR.
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
    required String model,
  });

  /// Lists models offered by the provider. [forTranscription] filters to
  /// audio/ASR-capable models; otherwise chat-capable models are returned.
  Future<List<RemoteModelInfo>> listModels({required bool forTranscription});

  /// Whether [transcribe] is supported by this provider.
  bool get supportsAudioTranscription;
}
