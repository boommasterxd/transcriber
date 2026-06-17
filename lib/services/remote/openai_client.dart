import '../transcription/transcription_service.dart';
import 'openai_compatible_client.dart';

/// OpenAI client: chat completions + native audio transcription + model listing.
class OpenAiClient extends OpenAiCompatibleClient {
  OpenAiClient({required super.apiKey, super.httpClient});

  @override
  String get baseUrl => 'https://api.openai.com/v1';

  @override
  bool get supportsAudioTranscription => true;

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
    required String model,
  }) =>
      transcribeOpenAi(audioPath, languageCode: languageCode, model: model);
}

/// OpenRouter client: OpenAI-compatible chat + model listing. No first-party ASR.
class OpenRouterClient extends OpenAiCompatibleClient {
  OpenRouterClient({required super.apiKey, super.httpClient});

  @override
  String get baseUrl => 'https://openrouter.ai/api/v1';

  @override
  Map<String, String> get extraHeaders => const {
        'HTTP-Referer': 'https://transcriber.app',
        'X-Title': 'Transcriber',
      };

  @override
  bool get supportsAudioTranscription => false;

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
    required String model,
  }) {
    throw UnsupportedError('OpenRouter bietet keine native Transkription.');
  }
}
