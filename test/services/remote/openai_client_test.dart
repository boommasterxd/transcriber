import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:transcriber/services/remote/openai_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

const _audioChatModel = 'gpt-audio-1.5';

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
  final audio = List.generate(64 * 1024 + 3, (index) => index % 256);
  const languageCode = 'de "Ö"\\\n';
  await withTemporaryAudio(
    prefix: 'openai-audio-chat-',
    bytes: audio,
    action: (file) async {
      late List<int> body;
      final httpClient = RecordingHttpClient(
        (_) async => jsonResponse({
          'choices': [
            {
              'message': {'content': 'Multimodal transcript'},
            },
          ],
        }),
        readBody: (stream) async {
          await file.writeAsBytes([3, 4], mode: FileMode.append);
          body = await stream.toBytes();
        },
      );
      final client = OpenAiClient(apiKey: 'secret-key', httpClient: httpClient);

      final result = await client.transcribe(
        file.path,
        modelId: _audioChatModel,
        languageCode: languageCode,
      );
      final captured = httpClient.requests.single;
      expect(captured.url.path, '/v1/chat/completions');
      expect(captured, isA<http.Abortable>());
      expect(captured, isNot(isA<http.Request>()));
      expect(captured.headers['Content-Type'], 'application/json');
      expect(captured.contentLength, body.length);
      _expectInlineAudioJson(body, audio, languageCode);
      expect(result.text, 'Multimodal transcript');
    },
  );
}

void _expectInlineAudioJson(
  List<int> body,
  List<int> audio,
  String languageCode,
) {
  expect(jsonDecode(utf8.decode(body)), {
    'model': _audioChatModel,
    'modalities': ['text'],
    'messages': [
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text':
                'Transcribe the attached audio verbatim. Return only the '
                'transcript as plain text. The spoken language is $languageCode.',
          },
          {
            'type': 'input_audio',
            'input_audio': {'data': base64Encode(audio), 'format': 'wav'},
          },
        ],
      },
    ],
  });
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
  test('rejects oversized transcription before upload', _testOversizedAudio);
}

Future<void> _testOversizedAudio() async {
  await _expectOversizedAudio('gpt-transcribe', 25000001);
  await _expectOversizedAudio(_audioChatModel, 20 * 1024 * 1024 + 1);
}

Future<void> _expectOversizedAudio(String modelId, int length) =>
    withTemporaryAudio(
      prefix: 'openai-audio-limit-',
      action: (file) async {
        final handle = await file.open(mode: FileMode.append);
        try {
          await handle.truncate(length);
        } finally {
          await handle.close();
        }

        final httpClient = scriptedHttpClient([]);
        final client = OpenAiClient(
          apiKey: 'secret-key',
          httpClient: httpClient,
        );
        await expectLater(
          client.transcribe(file.path, modelId: modelId),
          throwsA(
            isA<RemoteApiException>().having(
              (error) => error.message,
              'message',
              'The audio file is too large.',
            ),
          ),
        );
        expect(httpClient.requests, isEmpty);
      },
    );

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
