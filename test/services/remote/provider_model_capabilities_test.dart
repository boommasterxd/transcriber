import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/remote/provider_model_capabilities.dart';

void main() {
  group('OpenAI transcription capabilities', () {
    test('includes native transcription and multimodal audio models', () {
      const supported = [
        'gpt-transcribe',
        'gpt-4o-transcribe-diarize',
        'whisper-1',
        'gpt-audio-1.5',
        'gpt-4o-audio-preview',
      ];

      expect(
        supported.every(ProviderModelCapabilities.isOpenAiTranscriptionModel),
        isTrue,
      );
    });

    test('excludes audio families incompatible with batch transcription', () {
      const unsupported = [
        'gpt-realtime',
        'gpt-4o-realtime-preview',
        'gpt-4o-mini-tts',
        'omni-moderation-latest',
      ];

      expect(
        unsupported.any(ProviderModelCapabilities.isOpenAiTranscriptionModel),
        isFalse,
      );
    });
  });

  group('Gemini transcription capabilities', () {
    const generateContent = {'generateContent'};

    test('includes native transcription and general multimodal models', () {
      expect(
        ProviderModelCapabilities.isGeminiTranscriptionModel(
          'gemini-3.5-transcribe',
          const {},
        ),
        isTrue,
      );
      expect(
        ProviderModelCapabilities.isGeminiTranscriptionModel(
          'gemini-3.7-flash',
          generateContent,
        ),
        isTrue,
      );
    });

    test('excludes non-text-output and incompatible API families', () {
      const unsupported = [
        'gemini-embedding-001',
        'gemini-3-pro-image-preview',
        'gemini-2.5-flash-preview-tts',
        'gemini-2.5-flash-native-audio-live',
      ];

      expect(
        unsupported.any(
          (id) => ProviderModelCapabilities.isGeminiTranscriptionModel(
            id,
            generateContent,
          ),
        ),
        isFalse,
      );
    });
  });
}
