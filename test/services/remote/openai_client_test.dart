import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/services/remote/openai_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

void main() {
  _registerCatalogTest();
  _registerSummaryTest();
  _registerTranscriptionTest();
  _registerMultimodalTranscriptionTest();
  _registerProviderErrorTest();
  _registerMissingFileTest();
}

void _registerCatalogTest() {
  test(
    'lists models and tests a key through the authenticated catalog',
    _testCatalog,
  );
}

Future<void> _testCatalog() async {
  final httpClient = scriptedHttpClient(
    List.generate(
      3,
      (_) => jsonResponse({
        'data': [
          {'id': 'gpt-transcribe'},
          {'id': 'gpt-5.6-luna'},
          {'id': 'whisper-1'},
          {'id': 'gpt-audio-1.5'},
          {'id': 'gpt-4o-audio-preview'},
          {'id': 'gpt-realtime'},
          {'id': 'gpt-4o-mini-tts'},
          {'id': 'omni-moderation-latest'},
        ],
      }),
    ),
  );
  final client = OpenAiClient(apiKey: 'secret-key', httpClient: httpClient);

  await client.testConnection();
  final asr = await client.listModels(forTranscription: true);
  final summary = await client.listModels(forTranscription: false);

  expectCatalogRequests(
    httpClient,
    expectedPath: '/v1/models',
    headerName: 'authorization',
    headerValue: 'Bearer secret-key',
  );
  expect(asr.map((model) => model.id), [
    'gpt-4o-audio-preview',
    'gpt-audio-1.5',
    'gpt-transcribe',
    'whisper-1',
  ]);
  expect(summary.map((model) => model.id), ['gpt-5.6-luna']);
}

void _registerMultimodalTranscriptionTest() {
  test(
    'sends multimodal audio models through chat completions',
    _testMultimodalTranscription,
  );
}

Future<void> _testMultimodalTranscription() async {
  await withTemporaryAudio(
    prefix: 'openai-audio-chat-',
    bytes: [1, 2],
    action: (file) async {
      final httpClient = scriptedHttpClient([
        jsonResponse({
          'choices': [
            {
              'message': {'content': 'Multimodal transcript'},
            },
          ],
        }),
      ]);
      final client = OpenAiClient(apiKey: 'secret-key', httpClient: httpClient);

      final result = await client.transcribe(
        file.path,
        modelId: 'gpt-audio-1.5',
        languageCode: 'de',
      );
      final captured = httpClient.requests.single as http.Request;
      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      final messages = payload['messages'] as List;
      final content = (messages.single as Map)['content'] as List;

      expect(captured.url.path, '/v1/chat/completions');
      expect(payload['model'], 'gpt-audio-1.5');
      expect(payload['modalities'], ['text']);
      expect((content.first as Map)['text'], contains('language is de'));
      expect((content.last as Map)['input_audio'], {
        'data': 'AQI=',
        'format': 'wav',
      });
      expect(result.text, 'Multimodal transcript');
    },
  );
}

void _registerSummaryTest() {
  test('sends summary prompts to chat completions', _testSummary);
}

Future<void> _testSummary() async {
  final httpClient = scriptedHttpClient([
    jsonResponse({
      'choices': [
        {
          'message': {'content': 'summary'},
        },
      ],
    }),
  ]);
  final client = OpenAiClient(apiKey: 'secret-key', httpClient: httpClient);

  expect(
    await client.summarize(
      systemPrompt: 'system',
      userPrompt: 'user',
      modelId: 'gpt-5.6-luna',
    ),
    'summary',
  );
  final captured = httpClient.requests.single as http.Request;
  expect(captured.url.toString(), 'https://api.openai.com/v1/chat/completions');
  expect(jsonDecode(captured.body), {
    'model': 'gpt-5.6-luna',
    'messages': [
      {'role': 'system', 'content': 'system'},
      {'role': 'user', 'content': 'user'},
    ],
  });
}

void _registerTranscriptionTest() {
  test('sends gpt-transcribe as multipart', _testTranscription);
  test(
    'presents Opus as supported OGG without converting its bytes',
    () => _testTranscription(
      fileName: 'whatsapp-voice.opus',
      expectedUploadName: 'whatsapp-voice.ogg',
      expectedContentType: 'audio/ogg',
    ),
  );
}

Future<void> _testTranscription({
  String fileName = 'voice.wav',
  String? expectedUploadName,
  String? expectedContentType,
}) async {
  await withTemporaryAudio(
    prefix: 'openai-test-',
    fileName: fileName,
    bytes: [1, 2],
    action: (file) async {
      final httpClient = scriptedHttpClient([
        jsonResponse({
          'text': 'result',
          'languages': [
            {'code': 'de'},
          ],
        }),
      ]);
      final client = OpenAiClient(apiKey: 'secret-key', httpClient: httpClient);

      final result = await client.transcribe(
        file.path,
        modelId: 'gpt-transcribe',
        languageCode: 'de',
      );
      final captured = httpClient.requests.single as http.MultipartRequest;
      expect(
        captured.url.toString(),
        'https://api.openai.com/v1/audio/transcriptions',
      );
      expect(captured.headers['Authorization'], 'Bearer secret-key');
      expect(captured.fields, {
        'model': 'gpt-transcribe',
        'response_format': 'json',
        'language': 'de',
      });
      expect(captured.files.single.filename, expectedUploadName ?? fileName);
      if (expectedContentType != null) {
        expect(
          captured.files.single.contentType.toString(),
          expectedContentType,
        );
      }
      expect(result.text, 'result');
      expect(result.segments.single.text, 'result');
    },
  );
}

void _registerProviderErrorTest() {
  test('does not expose an API key from provider errors', _testProviderError);
}

Future<void> _testProviderError() async {
  final httpClient = scriptedHttpClient([
    textResponse('{"error":{"message":"token=secret-key"}}', statusCode: 401),
  ]);
  final client = OpenAiClient(apiKey: 'secret-key', httpClient: httpClient);

  await expectLater(
    client.testConnection(),
    throwsA(
      isA<RemoteApiException>()
          .having(
            (error) => error.message,
            'message',
            isNot(contains('secret-key')),
          )
          .having((error) => error.statusCode, 'statusCode', 401),
    ),
  );
}

void _registerMissingFileTest() {
  test('rejects an absent audio file without a request', _testMissingFile);
}

Future<void> _testMissingFile() async {
  final httpClient = scriptedHttpClient([jsonResponse({})]);
  final client = OpenAiClient(apiKey: 'key', httpClient: httpClient);

  await expectLater(
    client.transcribe('/missing/audio.wav', modelId: 'gpt-transcribe'),
    throwsA(isA<RemoteApiException>()),
  );
  expect(httpClient.requests, isEmpty);
}
