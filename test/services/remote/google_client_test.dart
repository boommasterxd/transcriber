import 'dart:convert';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

void main() {
  _registerCatalogTest();
  _registerCatalogPaginationTest();
  _registerSummaryTest();
  _registerTranscriptionTest();
  _registerMultimodalTranscriptionTest();
  _registerPollingTest();
  _registerProviderErrorTest();
}

void _registerCatalogTest() {
  test('tests a key and filters Gemini model catalog entries', _testCatalog);
}

Future<void> _testCatalog() async {
  final httpClient = scriptedHttpClient(
    List.generate(
      3,
      (_) => jsonResponse({
        'models': [
          {'name': 'models/gemini-3.5-transcribe'},
          {
            'name': 'models/gemini-3.7-flash',
            'displayName': 'Gemini Flash',
            'supportedGenerationMethods': ['generateContent'],
          },
          {
            'name': 'models/gemini-embedding',
            'supportedGenerationMethods': ['embedContent'],
          },
        ],
      }),
    ),
  );
  final client = GoogleClient(apiKey: 'secret-key', httpClient: httpClient);

  await client.testConnection();
  final asr = await client.listModels(forTranscription: true);
  final summary = await client.listModels(forTranscription: false);

  expectCatalogRequests(
    httpClient,
    expectedPath: '/v1beta/models',
    headerName: 'x-goog-api-key',
    headerValue: 'secret-key',
    expectedQueryKey: 'pageSize',
  );
  expect(asr.map((model) => model.id), [
    'gemini-3.5-transcribe',
    'gemini-3.7-flash',
  ]);
  expect(summary.single.display, 'Gemini Flash');
}

void _registerCatalogPaginationTest() {
  test('loads and deduplicates every Gemini model page', () async {
    final httpClient = scriptedHttpClient([
      jsonResponse({
        'models': [
          {
            'name': 'models/gemini-3.7-flash',
            'supportedGenerationMethods': ['generateContent'],
          },
        ],
        'nextPageToken': 'second-page',
      }),
      jsonResponse({
        'models': [
          {
            'name': 'models/gemini-3.7-flash',
            'supportedGenerationMethods': ['generateContent'],
          },
          {
            'name': 'models/gemini-3.1-pro-preview',
            'supportedGenerationMethods': ['generateContent'],
          },
        ],
      }),
    ]);
    final client = GoogleClient(apiKey: 'key', httpClient: httpClient);

    final models = await client.listModels(forTranscription: true);

    expect(models.map((model) => model.id), [
      'gemini-3.1-pro-preview',
      'gemini-3.7-flash',
    ]);
    expect(httpClient.requests, hasLength(2));
    expect(
      httpClient.requests.last.url.queryParameters['pageToken'],
      'second-page',
    );
  });
}

void _registerSummaryTest() {
  test(
    'uses generateContent for summaries with header authentication',
    _testSummary,
  );
  test('omits Gemini 3 thinking levels for older summary models', () async {
    final httpClient = scriptedHttpClient([
      jsonResponse({'candidates': []}),
    ]);
    final client = GoogleClient(apiKey: 'key', httpClient: httpClient);

    await client.summarize(
      systemPrompt: 'system',
      userPrompt: 'user',
      modelId: 'gemini-2.5-flash',
    );

    final request = httpClient.requests.single as http.Request;
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final config = body['generationConfig'] as Map<String, dynamic>;
    expect(config, isNot(contains('thinkingConfig')));
  });
}

Future<void> _testSummary() async {
  final httpClient = scriptedHttpClient([
    jsonResponse({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': 'summary'},
            ],
          },
        },
      ],
    }),
  ]);
  final client = GoogleClient(apiKey: 'secret-key', httpClient: httpClient);

  final result = await client.summarize(
    systemPrompt: 'system',
    userPrompt: 'user',
    modelId: 'gemini-3.7-flash',
  );
  final captured = httpClient.requests.single as http.Request;

  expect(result, 'summary');
  expect(captured.headers['x-goog-api-key'], 'secret-key');
  expect(captured.url.queryParameters, isEmpty);
  expect(jsonDecode(captured.body), {
    'systemInstruction': {
      'parts': [
        {'text': 'system'},
      ],
    },
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': 'user'},
        ],
      },
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'maxOutputTokens': 1024,
      'thinkingConfig': {'thinkingLevel': 'LOW'},
    },
  });
}

void _registerTranscriptionTest() {
  test(
    'uploads audio, creates an interaction, and deletes the remote file',
    _testTranscription,
  );
  test(
    'routes future unary ASR models through native interactions',
    () => _testTranscription(modelId: 'gemini-99-asr'),
  );
  test(
    'uploads WhatsApp Opus with native MIME metadata',
    () => _testTranscription(
      fileName: 'whatsapp-voice.opus',
      expectedMimeType: 'audio/opus',
    ),
  );
}

Future<void> _testTranscription({
  String fileName = 'voice.wav',
  String expectedMimeType = 'audio/wav',
  String modelId = 'gemini-3.5-transcribe',
}) async {
  await withTemporaryAudio(
    prefix: 'gemini-test-',
    fileName: fileName,
    bytes: [1, 2],
    action: (file) async {
      final httpClient = scriptedHttpClient([
        jsonResponse(
          {},
          headers: {'x-goog-upload-url': 'https://upload.test/session'},
        ),
        jsonResponse({
          'file': {
            'name': 'files/test-audio',
            'uri': 'https://files.test/test-audio',
            'mimeType': expectedMimeType,
            'state': 'ACTIVE',
          },
        }),
        jsonResponse({
          'status': 'completed',
          'steps': [
            {
              'type': 'model_output',
              'content': [
                {'type': 'text', 'text': 'Transcript'},
              ],
            },
          ],
        }),
        jsonResponse({}),
      ]);
      final client = GoogleClient(apiKey: 'secret-key', httpClient: httpClient);

      final result = await client.transcribe(
        file.path,
        modelId: modelId,
        languageCode: 'de',
      );
      expect(httpClient.requests, hasLength(4));
      expect(httpClient.requests[0].url.path, '/upload/v1beta/files');
      expect(
        httpClient.requests[0].headers['X-Goog-Upload-Header-Content-Type'],
        expectedMimeType,
      );
      expect(
        httpClient.requests[1].url.toString(),
        'https://upload.test/session',
      );
      expect(httpClient.requests[1].headers['Content-Type'], expectedMimeType);
      expect(httpClient.requests[2].url.path, '/v1beta/interactions');
      expect(httpClient.requests[3].method, 'DELETE');
      for (final request in httpClient.requests) {
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['x-goog-api-key'], 'secret-key');
      }
      final interaction =
          jsonDecode((httpClient.requests[2] as http.Request).body)
              as Map<String, dynamic>;
      expect(interaction['model'], modelId);
      expect(interaction['store'], isFalse);
      expect((interaction['input'] as List).single['type'], 'audio');
      expect(
        (interaction['input'] as List).single['mime_type'],
        expectedMimeType,
      );
      expect(interaction['generation_config']['transcription_config'], {
        'mode': {'type': 'smart'},
        'language_codes': ['de-DE'],
      });
      expect(result.text, 'Transcript');
      expect(result.segments.single.text, 'Transcript');
    },
  );
}

void _registerMultimodalTranscriptionTest() {
  test(
    'prompts a general multimodal Gemini model without transcription config',
    _testMultimodalTranscription,
  );
}

Future<void> _testMultimodalTranscription() async {
  await withTemporaryAudio(
    prefix: 'gemini-multimodal-',
    action: (file) async {
      final httpClient = scriptedHttpClient([
        jsonResponse(
          {},
          headers: {'x-goog-upload-url': 'https://upload.test/multimodal'},
        ),
        jsonResponse({
          'file': {
            'name': 'files/multimodal',
            'uri': 'https://files.test/multimodal',
            'mimeType': 'audio/wav',
            'state': 'ACTIVE',
          },
        }),
        jsonResponse({
          'status': 'completed',
          'steps': [
            {
              'content': [
                {'type': 'text', 'text': 'General transcript'},
              ],
            },
          ],
        }),
        jsonResponse({}),
      ]);
      final client = GoogleClient(apiKey: 'key', httpClient: httpClient);

      final result = await client.transcribe(
        file.path,
        modelId: 'gemini-3.7-flash',
        languageCode: 'en',
      );
      final interaction =
          jsonDecode((httpClient.requests[2] as http.Request).body)
              as Map<String, dynamic>;
      final input = interaction['input'] as List;

      expect(interaction['store'], isFalse);
      expect(input, hasLength(2));
      expect((input.first as Map)['type'], 'text');
      expect((input.first as Map)['text'], contains('language is en'));
      expect((input.last as Map)['type'], 'audio');
      expect(interaction, isNot(contains('generation_config')));
      expect(result.text, 'General transcript');
    },
  );
}

void _registerPollingTest() {
  test('polls a processing file before creating the interaction', _testPolling);
}

Future<void> _testPolling() async {
  await withTemporaryAudio(
    prefix: 'gemini-poll-',
    fileName: 'voice.mp3',
    action: (file) async {
      final httpClient = scriptedHttpClient([
        jsonResponse(
          {},
          headers: {'x-goog-upload-url': 'https://upload.test/poll'},
        ),
        jsonResponse({
          'file': {
            'name': 'files/poll',
            'uri': 'https://files.test/poll',
            'mimeType': 'audio/mpeg',
            'state': 'PROCESSING',
          },
        }),
        jsonResponse({'state': 'ACTIVE'}),
        jsonResponse({
          'status': 'completed',
          'steps': [
            {
              'content': [
                {'type': 'text', 'text': 'Transcript'},
              ],
            },
          ],
        }),
        jsonResponse({}),
      ]);
      final client = GoogleClient(
        apiKey: 'key',
        pollInterval: Duration.zero,
        delay: (_) async {},
        httpClient: httpClient,
      );

      await client.transcribe(file.path, modelId: 'gemini-3.5-transcribe');
      expect(httpClient.requests, hasLength(5));
    },
  );
}

void _registerProviderErrorTest() {
  test(
    'cleans up the uploaded file when interaction fails',
    _testProviderError,
  );
}

Future<void> _testProviderError() async {
  await withTemporaryAudio(
    prefix: 'gemini-error-',
    action: (file) async {
      final httpClient = scriptedHttpClient([
        jsonResponse(
          {},
          headers: {'x-goog-upload-url': 'https://upload.test/error'},
        ),
        jsonResponse({
          'file': {
            'name': 'files/error',
            'uri': 'https://files.test/error',
            'state': 'ACTIVE',
          },
        }),
        textResponse(
          '{"error":{"message":"token=secret-key"}}',
          statusCode: 500,
        ),
        jsonResponse({}),
      ]);
      final client = GoogleClient(apiKey: 'secret-key', httpClient: httpClient);

      await expectLater(
        client.transcribe(file.path, modelId: 'gemini-3.5-transcribe'),
        throwsA(
          isA<RemoteApiException>().having(
            (error) => error.message,
            'message',
            isNot(contains('secret-key')),
          ),
        ),
      );
      expect(httpClient.requests, hasLength(4));
    },
  );
}
