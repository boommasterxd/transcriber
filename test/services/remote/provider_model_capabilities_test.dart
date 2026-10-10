import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/remote/provider_model_capabilities.dart';

void main() {
  _registerOpenAiSummaryTests();
  _registerOpenAiTranscriptionTests();
  _registerGeminiTests();
}

void _registerOpenAiSummaryTests() {
  group('OpenAI summary compatibility', () {
    for (final id in [
      'gpt-3.5-turbo-0125',
      'gpt-4-0613',
      'gpt-4-turbo-preview',
      'gpt-4o-mini-2024-07-18',
      'gpt-4.1-nano',
      'gpt-5-mini',
      'gpt-5.2-2025-12-11',
      'gpt-5.4-nano',
      'gpt-5.5',
      'gpt-5.6-luna',
      'gpt-6.1-sol',
      'o1-2024-12-17',
      'o3-mini',
      'o4-mini',
      'gpt-99-nova-2040-01-01',
      'chatgpt-99-latest',
      'o99-mini',
      'gpt-unknown',
      'gpt-7',
      'gpt-4o-2024-07-18-extra',
      'o1-preview',
      'o1-mini',
      'chatgpt-4o-latest',
    ]) {
      test('accepts current and future text model names $id', () {
        expect(ProviderModelCapabilities.isOpenAiSummaryModel(id), isTrue);
      });
    }
    for (final id in [
      'gpt-5.6-luna-codex',
      'gpt-5-pro',
      'o3-deep-research',
      'gpt-4o-search-preview',
      'sora-2',
      'davinci-002',
      'gpt-99-agent',
      'gpt-99-computer-use',
      'gpt-99-oss',
      'gpt-99-audio',
      'gpt-99-transcription',
      'gpt-99-moderation',
      'gpt-99-embedding',
    ]) {
      test('rejects named specialists and unsupported text families $id', () {
        expect(ProviderModelCapabilities.isOpenAiSummaryModel(id), isFalse);
      });
    }
  });
}

void _registerOpenAiTranscriptionTests() {
  const cases = <String, bool>{
    'whisper-1': false,
    'gpt-transcribe': false,
    'gpt-4o-transcribe-diarize': false,
    'gpt-4o-mini-transcribe-2025-12-15': false,
    'gpt-audio-1.5': true,
    'gpt-audio-mini': true,
    'gpt-4o-audio-preview-2024-12-17': true,
    'gpt-4o-mini-audio-preview': true,
    'gpt-99-speech-transcribe-2040-01-01': false,
    'gpt-future-asr': false,
    'whisper-99': false,
    'gpt-audio-99': true,
    'gpt-4o-audio': true,
    'gpt-4o-audio-preview-unknown': true,
    'gpt-transcribe-future': false,
  };
  for (final entry in cases.entries) {
    test('routes supported audio model ${entry.key}', () {
      expect(
        ProviderModelCapabilities.isOpenAiTranscriptionModel(entry.key),
        isTrue,
      );
      expect(
        ProviderModelCapabilities.usesOpenAiAudioChat(entry.key),
        entry.value,
      );
      expect(
        ProviderModelCapabilities.usesOpenAiTranscriptionEndpoint(entry.key),
        !entry.value,
      );
      expect(
        ProviderModelCapabilities.isOpenAiSummaryModel(entry.key),
        isFalse,
      );
    });
  }
  for (final id in [
    'custom-transcribe',
    'gpt-live-transcribe',
    'audio-helper',
    'gpt-realtime-2.1',
    'gpt-4o-mini-tts',
    'gpt-4o',
    'gpt-audio-99-tts',
    'gpt-asr-99-realtime',
    'unknown-asr',
    'custom-whisper',
    'other-audio',
  ]) {
    test('rejects incompatible audio model $id', () {
      expect(ProviderModelCapabilities.isOpenAiTranscriptionModel(id), isFalse);
    });
  }
}

void _registerGeminiTests() {
  for (final id in [
    'gemini-2.5-pro-preview-06-05',
    'gemini-2.5-flash-lite-preview-09-2025',
    'gemini-3-flash-preview',
    'gemini-3.1-pro-preview',
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash-lite',
    'gemini-3.6-flash',
    'gemini-3.7-flash',
    'gemini-3.8-flash',
    'gemini-flash-latest',
    'gemini-pro-latest',
    'gemini-99-nova-preview-2040-01-01',
    'gemini-4-flash',
    'gemini-3.7-pro',
    'gemini-3.8-flash-future',
    'gemini-2.0-flash',
  ]) {
    test(
      'requires generateContent for current and future Gemini models $id',
      () {
        _expectGeminiCompatibility(id, const {'generateContent'}, true);
        _expectGeminiCompatibility(id, const {'embedContent'}, false);
        _expectGeminiCompatibility(id, const {}, false);
      },
    );
  }
  for (final id in [
    '',
    'gemini-3.8-flash-preview-image',
    'gemini-3.8-flash-tts-preview',
    'gemini-3.8-flash-robotics',
    'gemini-3.8-flash-live',
    'gemini-3.5-transcribe-live',
    '../gemini-3.8-flash',
    'GEMINI-3.8-FLASH',
    'gemini-3.8-flash\n',
    'gemini-omni-future',
    'gemini-future-video',
    'gemini-future-embedding',
    'gemini-future-tts',
    'gemini-99-text-to-speech',
    'gemini-99-speech-generation',
  ]) {
    test('rejects named Gemini specialists ${id.trim()}', () {
      _expectGeminiCompatibility(id, const {'generateContent'}, false);
      expect(
        ProviderModelCapabilities.usesGeminiNativeTranscription(id),
        isFalse,
      );
    });
  }
  test('accepts unary Gemini ASR independently of generation metadata', () {
    const id = 'gemini-3.5-transcribe';
    expect(ProviderModelCapabilities.usesGeminiNativeTranscription(id), isTrue);
    expect(
      ProviderModelCapabilities.isGeminiTranscriptionModel(id, const {}),
      isTrue,
    );
    expect(
      ProviderModelCapabilities.isGeminiSummaryModel(id, const {
        'generateContent',
      }),
      isFalse,
    );
  });
  _registerMetadataTests();
  _registerSafeIdTests();
  _registerFutureAsrTests();
}

void _registerMetadataTests() {
  for (final label in [
    'Gemini Future Image',
    'Nano Banana',
    'Gemini Omni Flash',
    'Gemini Robotics',
    'Text to Speech',
  ]) {
    test('rejects specialist display names $label', () {
      _expectMetadataRejected(displayName: label);
    });
  }
  for (final description in [
    'Specialized model for image generation.',
    'New video editing model.',
    'Speech synthesis for studio audio.',
    'Text-to-speech for expressive voices.',
    'A model for embeddings.',
    'Robotics reasoning.',
    'Omni media model.',
    'Nano Banana image model.',
    'A new image model.',
    'Live audio model.',
  ]) {
    test('rejects explicit specialist descriptions $description', () {
      _expectMetadataRejected(description: description);
    });
  }
  test('keeps input modalities and generic abilities eligible', () {
    const description =
        'General model supports text and image input, audio understanding, '
        'audio transcription, coding, research and agents.';
    for (final classify in [
      ProviderModelCapabilities.isGeminiSummaryModel,
      ProviderModelCapabilities.isGeminiTranscriptionModel,
    ]) {
      expect(
        classify('gemini-99-nova', const {
          'generateContent',
        }, description: description),
        isTrue,
      );
    }
  });
  test('uses text-only metadata only for the transcription purpose', () {
    const id = 'next-general-model';
    const methods = {'generateContent'};
    const description = 'A text-only model for summaries.';
    expect(
      ProviderModelCapabilities.isGeminiSummaryModel(
        id,
        methods,
        description: description,
      ),
      isTrue,
    );
    expect(
      ProviderModelCapabilities.isGeminiTranscriptionModel(
        id,
        methods,
        description: description,
      ),
      isFalse,
    );
    expect(
      ProviderModelCapabilities.isGeminiTranscriptionModel('gemma-99', methods),
      isFalse,
    );
    expect(
      ProviderModelCapabilities.isGeminiTranscriptionModel(
        id,
        methods,
        displayName: 'Text Only',
      ),
      isFalse,
    );
  });
  for (final role in ['transcribe', 'transcription', 'asr']) {
    test('rejects ASR metadata from summaries $role', () {
      for (final displayName in [true, false]) {
        expect(
          ProviderModelCapabilities.isGeminiSummaryModel(
            'gemini-next',
            const {'generateContent'},
            displayName: displayName ? 'Gemini $role' : null,
            description: displayName ? null : 'Dedicated $role model.',
          ),
          isFalse,
        );
      }
    });
  }
}

void _expectMetadataRejected({String? displayName, String? description}) {
  for (final classify in [
    ProviderModelCapabilities.isGeminiSummaryModel,
    ProviderModelCapabilities.isGeminiTranscriptionModel,
  ]) {
    expect(
      classify(
        'gemini-next',
        const {'generateContent'},
        displayName: displayName,
        description: description,
      ),
      isFalse,
    );
  }
}

void _registerSafeIdTests() {
  for (final invalid in [
    '',
    '../other',
    'gpt-99/other',
    'gemini-next?key=x',
    'gpt-99#fragment',
    'gpt-99%2fother',
    'gpt-99\\other',
    'gpt-99\n',
    'gpt-99 ',
    'GEMINI-99',
    'gpt--99',
    'gpt-99..other',
    'gpt-${'x' * 201}',
  ]) {
    test('rejects unsafe model ID ${invalid.trim()}', () {
      expect(ProviderModelCapabilities.isOpenAiSummaryModel(invalid), isFalse);
      expect(
        ProviderModelCapabilities.isOpenAiTranscriptionModel(invalid),
        isFalse,
      );
      _expectGeminiCompatibility(invalid, const {'generateContent'}, false);
      expect(
        ProviderModelCapabilities.usesGeminiNativeTranscription(invalid),
        isFalse,
      );
    });
  }
}

void _registerFutureAsrTests() {
  for (final id in ['gemini-99-transcribe', 'gemini-future-asr']) {
    test('routes future unary ASR model $id without admitting Live', () {
      expect(
        ProviderModelCapabilities.usesGeminiNativeTranscription(id),
        isTrue,
      );
      expect(
        ProviderModelCapabilities.isGeminiTranscriptionModel(id, const {}),
        isTrue,
      );
      expect(
        ProviderModelCapabilities.isGeminiSummaryModel(id, const {
          'generateContent',
        }),
        isFalse,
      );
      expect(
        ProviderModelCapabilities.usesGeminiNativeTranscription('$id-live'),
        isFalse,
      );
    });
  }
}

void _expectGeminiCompatibility(
  String id,
  Set<String> methods,
  bool compatible,
) {
  expect(
    ProviderModelCapabilities.isGeminiSummaryModel(id, methods),
    compatible,
  );
  expect(
    ProviderModelCapabilities.isGeminiTranscriptionModel(id, methods),
    compatible,
  );
}
