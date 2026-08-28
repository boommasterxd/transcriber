import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/remote/openai_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

void main() {
  _registerSummaryContractTests();
  _registerEmptyTranscriptionTest();
  _registerUnsupportedModelTest();
  _registerUnsupportedInlineFormatTest();
  _registerSizeLimitTest();
}

void _registerUnsupportedModelTest() {
  test('rejects a text-only model before sending audio', () async {
    await withTemporaryAudio(
      prefix: 'openai-text-model-',
      action: (file) async {
        final httpClient = scriptedHttpClient([jsonResponse({})]);
        final client = OpenAiClient(apiKey: 'key', httpClient: httpClient);

        await expectLater(
          client.transcribe(file.path, modelId: 'gpt-text-only'),
          throwsA(isA<RemoteApiException>()),
        );
        expect(httpClient.requests, isEmpty);
      },
    );
  });
}

void _registerUnsupportedInlineFormatTest() {
  test('rejects unsupported inline audio formats before a request', () async {
    await withTemporaryAudio(
      prefix: 'openai-inline-format-',
      fileName: 'voice.m4a',
      action: (file) async {
        final httpClient = scriptedHttpClient([jsonResponse({})]);
        final client = OpenAiClient(apiKey: 'key', httpClient: httpClient);

        await expectLater(
          client.transcribe(file.path, modelId: 'gpt-audio-1.5'),
          throwsA(
            isA<RemoteApiException>().having(
              (error) => error.message,
              'message',
              contains('WAV or MP3'),
            ),
          ),
        );
        expect(httpClient.requests, isEmpty);
      },
    );
  });
}

void _registerSummaryContractTests() {
  group('OpenAiClient summary response contracts', () {
    test('returns empty text when the choices array is empty', () async {
      expect(await _summarize({'choices': []}), isEmpty);
    });

    test('returns empty text when the first choice has no message', () async {
      expect(
        await _summarize({
          'choices': [{}],
        }),
        isEmpty,
      );
    });

    test('rejects malformed successful JSON', () async {
      await expectLater(
        _summarize('{malformed-json'),
        throwsA(
          isA<RemoteApiException>().having(
            (error) => error.message,
            'message',
            'OpenAI response was invalid.',
          ),
        ),
      );
    });
  });
}

Future<String> _summarize(Object body) {
  final response = body is String ? textResponse(body) : jsonResponse(body);
  final client = OpenAiClient(
    apiKey: 'key',
    httpClient: scriptedHttpClient([response]),
  );
  return client.summarize(
    systemPrompt: 'system',
    userPrompt: 'user',
    modelId: 'summary-model',
  );
}

void _registerEmptyTranscriptionTest() {
  test(
    'returns an empty transcription for an empty text response',
    _testEmptyTranscription,
  );
}

Future<void> _testEmptyTranscription() async {
  await withTemporaryAudio(
    prefix: 'openai-empty-',
    action: (file) async {
      final client = OpenAiClient(
        apiKey: 'key',
        httpClient: scriptedHttpClient([
          jsonResponse({'text': '  '}),
        ]),
      );

      final result = await client.transcribe(
        file.path,
        modelId: 'gpt-transcribe',
      );
      expect(result.text, isEmpty);
      expect(result.segments, isEmpty);
    },
  );
}

void _registerSizeLimitTest() {
  test(
    'rejects an audio file above the provider size limit locally',
    () => expectOversizedAudioRejected(
      prefix: 'openai-size-',
      transcribe: (path, httpClient) => OpenAiClient(
        apiKey: 'key',
        httpClient: httpClient,
      ).transcribe(path, modelId: 'gpt-transcribe'),
    ),
  );
}
