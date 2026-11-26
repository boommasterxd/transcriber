import 'dart:convert';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/services/remote/openai_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

void main() {
  _registerSummaryTest();
  _registerTranscriptionTest();
  _registerMultimodalTranscriptionTest();
  _registerProviderErrorTest();
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
}

Future<void> _testTranscription({
  String fileName = 'private-conversation.WAV',
  String expectedUploadName = 'audio.wav',
  String expectedContentType = 'audio/wav',
  String modelId = 'gpt-transcribe',
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
        modelId: modelId,
        languageCode: 'de',
      );
      final captured = httpClient.requests.single as http.MultipartRequest;
      expect(
        captured.url.toString(),
        'https://api.openai.com/v1/audio/transcriptions',
      );
      expect(captured.headers['Authorization'], 'Bearer secret-key');
      expect(captured.fields, {
        'model': modelId,
        'response_format': 'json',
        if (modelId.contains('diarize')) 'chunking_strategy': 'auto',
        'language': 'de',
      });
      expect(captured.followRedirects, isFalse);
      expect(captured.files.single.filename, expectedUploadName);
      expect(captured.files.single.contentType.toString(), expectedContentType);
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
