import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/services/remote/anthropic_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';

void main() {
  _registerChatTests();
  _registerModelTests();
  _registerTranscriptionTests();
}

void _registerChatTests() {
  group('AnthropicClient.chat', () {
    test('sends the Messages request and joins UTF-8 text blocks', () async {
      late http.Request captured;
      final httpClient = RecordingHttpClient((request) async {
        captured = request as http.Request;
        return jsonResponse({
          'content': [
            {'type': 'text', 'text': ' Grüß '},
            {'type': 'tool_use', 'text': 'ignored'},
            {'type': 'text', 'text': 'dich '},
          ],
        });
      });
      final client = AnthropicClient(
        apiKey: 'test-key',
        httpClient: httpClient,
      );

      final result = await client.chat(
        system: 'system ä',
        user: 'user ö',
        modelId: 'claude-test',
      );

      expect(result, 'Grüß dich');
      expect(captured.method, 'POST');
      expect(captured.url, Uri.parse('https://api.anthropic.com/v1/messages'));
      expect(captured.headers['x-api-key'], 'test-key');
      expect(captured.headers['anthropic-version'], '2023-06-01');
      expect(captured.headers['content-type'], contains('application/json'));
      expect(jsonDecode(captured.body), {
        'model': 'claude-test',
        'max_tokens': 2048,
        'system': 'system ä',
        'messages': [
          {'role': 'user', 'content': 'user ö'},
        ],
      });
    });

    test('returns empty text for missing or empty content', () async {
      var responseIndex = 0;
      final responses = [
        <String, Object?>{},
        {'content': <Object?>[]},
      ];
      final httpClient = RecordingHttpClient((_) async {
        return jsonResponse(responses[responseIndex++]);
      });
      final client = AnthropicClient(apiKey: 'key', httpClient: httpClient);

      expect(await _chat(client), '');
      expect(await _chat(client), '');
    });

    test('surfaces a structured provider error with status', () async {
      final httpClient = RecordingHttpClient((_) async {
        return jsonResponse({
          'error': {'message': 'Bad key'},
        }, statusCode: 401);
      });
      final client = AnthropicClient(apiKey: 'key', httpClient: httpClient);

      await expectLater(
        _chat(client),
        throwsA(
          isA<RemoteApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having(
                (error) => error.message,
                'message',
                'Anthropic error (401): Bad key',
              ),
        ),
      );
    });

    test('rejects malformed successful JSON', () async {
      final client = AnthropicClient(
        apiKey: 'key',
        httpClient: RecordingHttpClient((_) async => textResponse('{broken')),
      );
      await expectLater(_chat(client), throwsFormatException);
    });
  });
}

void _registerModelTests() {
  group('AnthropicClient.listModels', () {
    test('skips the request for unsupported transcription models', () async {
      final httpClient = RecordingHttpClient((_) async {
        fail('No request expected');
      });
      final client = AnthropicClient(apiKey: 'key', httpClient: httpClient);

      expect(await client.listModels(forTranscription: true), isEmpty);
      expect(httpClient.requests, isEmpty);
    });

    test('requests and decodes model identifiers and labels', () async {
      late http.Request captured;
      final httpClient = RecordingHttpClient((request) async {
        captured = request as http.Request;
        return jsonResponse({
          'data': [
            {'id': 'claude-b', 'display_name': 'Claude Bö'},
            {'id': 'claude-a'},
          ],
        });
      });
      final client = AnthropicClient(apiKey: 'secret', httpClient: httpClient);

      final models = await client.listModels(forTranscription: false);

      expect(captured.method, 'GET');
      expect(
        captured.url,
        Uri.parse('https://api.anthropic.com/v1/models?limit=100'),
      );
      expect(captured.headers['x-api-key'], 'secret');
      expect(models.map((model) => model.id), ['claude-b', 'claude-a']);
      expect(models.map((model) => model.label), ['Claude Bö', null]);
    });

    test('uses an empty list when data is absent', () async {
      final client = AnthropicClient(
        apiKey: 'key',
        httpClient: RecordingHttpClient((_) async => jsonResponse({})),
      );
      expect(await client.listModels(forTranscription: false), isEmpty);
    });
  });
}

void _registerTranscriptionTests() {
  test('reports unsupported audio transcription synchronously', () {
    final client = AnthropicClient(
      apiKey: 'key',
      httpClient: RecordingHttpClient((_) async => jsonResponse({})),
    );

    expect(client.supportsAudioTranscription, isFalse);
    expect(
      () => client.transcribe('audio.wav', model: 'model'),
      throwsUnsupportedError,
    );
  });
}

Future<String> _chat(AnthropicClient client) {
  return client.chat(system: 'system', user: 'user', modelId: 'model');
}
