import '../remote/remote_api_client.dart';
import '../service_exceptions.dart';
import 'transcription_service.dart';

/// [TranscriptionService] backed by a cloud provider's ASR endpoint. Providers
/// without native ASR (Anthropic, OpenRouter) raise a clear error.
class RemoteTranscriptionService implements TranscriptionService {
  RemoteTranscriptionService(this.client);

  final RemoteApiClient client;

  @override
  Future<TranscriptionResult> transcribe(String audioPath, {String? languageCode}) {
    if (!client.supportsAudioTranscription) {
      throw const RemoteApiException(
        'Dieser Anbieter unterstützt keine Audio-Transkription. '
        'Wähle OpenAI oder Google, oder verarbeite auf dem Gerät.',
      );
    }
    return client.transcribe(audioPath, languageCode: languageCode);
  }
}
