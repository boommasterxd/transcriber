import 'package:http/http.dart' as http;

import '../transcription/transcription_service.dart';
import 'openai_compatible_client.dart';

/// OpenAI client: chat completions + native audio transcription.
class OpenAiClient extends OpenAiCompatibleClient {
  OpenAiClient({required super.apiKey, super.httpClient});

  static const _transcribeModel = 'gpt-4o-transcribe';

  @override
  String get baseUrl => 'https://api.openai.com/v1';

  @override
  bool get supportsAudioTranscription => true;

  @override
  String get asrLabel => 'gpt-4o-transcribe';

  @override
  Future<TranscriptionResult> transcribe(String audioPath, {String? languageCode}) =>
      transcribeOpenAi(audioPath, languageCode: languageCode, model: _transcribeModel);
}

/// OpenRouter client: OpenAI-compatible chat. No first-party ASR endpoint.
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
  String get asrLabel => '—';

  @override
  Future<TranscriptionResult> transcribe(String audioPath, {String? languageCode}) {
    throw UnsupportedError('OpenRouter bietet keine native Transkription.');
  }
}
