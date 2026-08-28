import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/services/remote/openai_client.dart';

import 'http_test_client.dart';

void main() {
  _registerOpenAiTests();
  _registerOpenRouterTests();
}

void _registerOpenAiTests() {
  test(
    'OpenAiClient uses OpenAI endpoints and supports transcription',
    () async {
      var requestIndex = 0;
      final responses = [
        {
          'choices': [
            {
              'message': {'content': 'answer'},
            },
          ],
        },
        {'data': <Object?>[]},
      ];
      final httpClient = RecordingHttpClient((request) async {
        return jsonResponse(responses[requestIndex++]);
      });
      final client = OpenAiClient(apiKey: 'openai-key', httpClient: httpClient);

      expect(client.supportsAudioTranscription, isTrue);
      expect(await client.chat(system: 's', user: 'u', modelId: 'm'), 'answer');
      expect(await client.listModels(forTranscription: false), isEmpty);
      expect(httpClient.requests.map((request) => request.url.toString()), [
        'https://api.openai.com/v1/chat/completions',
        'https://api.openai.com/v1/models',
      ]);
    },
  );

  test(
    'OpenAiClient delegates transcription to its multipart endpoint',
    () async {
      final directory = await Directory.systemTemp.createTemp('openai-test-');
      final file = await File('${directory.path}/voice.wav').writeAsBytes([1]);
      late http.MultipartRequest captured;
      final client = OpenAiClient(
        apiKey: 'openai-key',
        httpClient: RecordingHttpClient((request) async {
          captured = request as http.MultipartRequest;
          return jsonResponse({'text': 'result'});
        }),
      );

      try {
        final result = await client.transcribe(file.path, model: 'whisper-1');
        expect(
          captured.url.toString(),
          'https://api.openai.com/v1/audio/transcriptions',
        );
        expect(captured.headers['Authorization'], 'Bearer openai-key');
        expect(result.text, 'result');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}

void _registerOpenRouterTests() {
  test('OpenRouterClient adds attribution headers to requests', () async {
    late http.Request captured;
    final client = OpenRouterClient(
      apiKey: 'router-key',
      httpClient: RecordingHttpClient((request) async {
        captured = request as http.Request;
        return jsonResponse({'data': []});
      }),
    );

    expect(client.supportsAudioTranscription, isFalse);
    expect(await client.listModels(forTranscription: false), isEmpty);
    expect(captured.url.toString(), 'https://openrouter.ai/api/v1/models');
    expect(captured.headers['authorization'], 'Bearer router-key');
    expect(captured.headers['http-referer'], 'https://transcriber.app');
    expect(captured.headers['x-title'], 'Transcriber');
  });

  test('OpenRouterClient rejects transcription without a request', () {
    final httpClient = RecordingHttpClient((_) async {
      fail('No request expected');
    });
    final client = OpenRouterClient(
      apiKey: 'router-key',
      httpClient: httpClient,
    );

    expect(
      () => client.transcribe('audio.wav', model: 'whisper'),
      throwsUnsupportedError,
    );
    expect(httpClient.requests, isEmpty);
  });
}
