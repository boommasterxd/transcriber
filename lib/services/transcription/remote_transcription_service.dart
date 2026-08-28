import '../remote/remote_api_client.dart';
import 'transcription_service.dart';

/// [TranscriptionService] backed by a cloud provider's ASR endpoint.
class RemoteTranscriptionService implements TranscriptionService {
  RemoteTranscriptionService(this.client, this.model);

  final TranscriptionProviderClient client;
  final String model;

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
  }) {
    return client.transcribe(
      audioPath,
      languageCode: languageCode,
      modelId: model,
    );
  }
}
