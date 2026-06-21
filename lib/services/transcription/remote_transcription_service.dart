import '../remote/remote_api_client.dart';
import '../service_exceptions.dart';
import 'transcription_service.dart';

/// [TranscriptionService] backed by a cloud provider's ASR endpoint. Providers
/// without native ASR (Anthropic, OpenRouter) raise a clear error.
class RemoteTranscriptionService implements TranscriptionService {
  RemoteTranscriptionService(this.client, this.model);

  final RemoteApiClient client;
  final String model;

  @override
  Future<TranscriptionResult> transcribe(String audioPath, {String? languageCode}) {
    if (!client.supportsAudioTranscription) {
      throw const RemoteApiException(
        'This provider does not support audio transcription. '
        'Choose OpenAI or Google, or use on-device processing.',
      );
    }
    return client.transcribe(audioPath, languageCode: languageCode, model: model);
  }
}
