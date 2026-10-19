import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/remote/openai_client.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

void main() {
  for (final google in [false, true]) {
    group(google ? 'Gemini catalog' : 'OpenAI catalog', () {
      test(
        'returns sorted distinct models compatible with each purpose',
        () => _testCatalog(google),
      );
      _registerEmptyCatalogTests(google);
      _registerUnsupportedSelectionTests(google);
    });
  }
}

void _registerEmptyCatalogTests(bool google) {
  for (final catalog in [null, {}, 'invalid-catalog', []]) {
    test('returns no models for non-list or empty catalog $catalog', () {
      return _testEmptyCatalog(google, catalog);
    });
  }
}

Future<void> _testCatalog(bool google) async {
  final response = {google ? 'models' : 'data': _catalogEntries(google)};
  final httpClient = scriptedHttpClient([
    jsonResponse(response),
    jsonResponse(response),
  ]);
  final client = _client(google, httpClient);

  final transcription = await client.listModels(forTranscription: true);
  final summary = await client.listModels(forTranscription: false);

  expect(
    transcription.map((model) => model.id),
    google
        ? [
            'gemini-3.5-transcribe',
            'gemini-3.8-flash',
            'gemini-99-nova',
            'gemini-flash-lite-latest',
          ]
        : [
            'gpt-4o-mini-transcribe-2025-12-15',
            'gpt-audio-1.5',
            'gpt-audio-99',
            'whisper-99',
          ],
  );
  expect(
    summary.map((model) => model.id),
    google
        ? ['gemini-3.8-flash', 'gemini-99-nova', 'gemini-flash-lite-latest']
        : ['gpt-4.1-mini-2025-04-14', 'gpt-6-sol', 'gpt-99-nova'],
  );
  expect(httpClient.requests, hasLength(2));
}

List<Object?> _catalogEntries(bool google) {
  if (!google) {
    return [
      for (final id in [
        'gpt-6-sol',
        'gpt-audio-1.5',
        'gpt-audio-99',
        'whisper-99',
        'gpt-99-nova',
        'gpt-4o-mini-transcribe-2025-12-15',
        'gpt-4.1-mini-2025-04-14',
        'gpt-6-sol',
        'gpt-image-1',
        'text-embedding-3-small',
        'computer-use-preview',
        'gpt-5.1-codex',
        'o3-pro',
        'gpt-4o-mini-search-preview',
        'gpt-realtime-mini',
        'gpt-live-audio',
        'helper-transcribe',
        'gpt-4.1-mini/../../other',
        '',
        null,
        1,
      ])
        {'id': id},
      [],
      null,
    ];
  }
  return [
    for (final id in [
      'gemini-flash-lite-latest',
      'gemini-3.8-flash',
      'gemini-99-nova',
      'gemini-3.5-transcribe',
      'gemini-3.8-flash',
      'gemini-nano-banana-2.1',
      'gemini-omni-1.1-flash',
      'gemini-robotics-er-2-preview',
      'gemini-3.1-flash-image',
      'gemini-3.8-flash-tts',
      'gemini-99-text-to-speech',
      'gemini-99-speech-generation',
      'gemini-3.8-live',
      'gemini-3.5-transcribe-live',
      'gemini-3.1-pro-preview/other',
      'other/models/gemini-3.8-flash',
    ])
      {
        'name': 'models/$id',
        'supportedGenerationMethods': ['generateContent'],
      },
    for (final methods in [
      null,
      'generateContent',
      ['embedContent'],
      [42],
    ])
      {'name': 'models/gemini-2.5-pro', 'supportedGenerationMethods': methods},
    {
      'name': 1,
      'supportedGenerationMethods': ['generateContent'],
    },
    {},
    {
      'name': 'models/gemini-99-studio',
      'displayName': 'Next Image',
      'description': 'Specialist image generation model.',
      'supportedGenerationMethods': ['generateContent'],
    },
    null,
  ];
}

Future<void> _testEmptyCatalog(bool google, Object? catalog) async {
  final response = {google ? 'models' : 'data': catalog};
  final client = _client(google, scriptedHttpClient([jsonResponse(response)]));

  expect(await client.listModels(forTranscription: false), isEmpty);
}

void _registerUnsupportedSelectionTests(bool google) {
  final ids = google
      ? [
          'gemini-omni-1.1-flash',
          'gemini-3.8-flash-image',
          'gemini-robotics-er-1.6-preview',
          'gemini-3.8-flash-lite-tts',
          'gemini-nano-banana-2.1',
          'gemini-99-text-to-speech',
          'gemini-99-speech-generation',
          '../transcribe',
        ]
      : [
          'custom-future-transcribe',
          'unknown-audio',
          'gpt-live-transcribe',
          'gpt-image-1-mini',
          'gpt-5.1-codex',
          'o3-pro',
        ];
  for (final id in ids) {
    test(
      'rejects incompatible selection $id without sending content',
      () async {
        await withTemporaryAudio(
          prefix: 'unsupported-model-',
          action: (file) async {
            final httpClient = scriptedHttpClient([]);
            final client = _client(google, httpClient);

            await expectLater(
              client.summarize(
                systemPrompt: 'system',
                userPrompt: 'user',
                modelId: id,
              ),
              throwsA(isA<RemoteApiException>()),
            );
            await expectLater(
              client.transcribe(file.path, modelId: id),
              throwsA(isA<RemoteApiException>()),
            );
            expect(httpClient.requests, isEmpty);
          },
        );
      },
    );
  }
}

RemoteProviderClient _client(bool google, http.Client httpClient) => google
    ? GoogleClient(apiKey: 'test-key', httpClient: httpClient)
    : OpenAiClient(apiKey: 'test-key', httpClient: httpClient);
