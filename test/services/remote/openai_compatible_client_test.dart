import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/data/models/transcription_result.dart';
import 'package:transcriber/services/remote/openai_compatible_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';

void main() {
  _registerChatTests();
  _registerModelTests();
  _registerTranscriptionSuccessTests();
  _registerTranscriptionFailureTests();
}

void _registerChatTests() {
  group('OpenAiCompatibleClient.chat', () {
    test(
      'sends compatible headers and UTF-8 messages, then trims text',
      () async {
        late http.Request captured;
        final client = _TestClient(
          RecordingHttpClient((request) async {
            captured = request as http.Request;
            return jsonResponse({
              'choices': [
                {
                  'message': {'content': ' Grüß dich '},
                },
              ],
            });
          }),
        );

        final result = await client.chat(
          system: 'System ä',
          user: 'User ö',
          modelId: 'chat-model',
        );

        expect(result, 'Grüß dich');
        expect(captured.method, 'POST');
        expect(
          captured.url,
          Uri.parse('https://example.test/v1/chat/completions'),
        );
        expect(captured.headers['authorization'], 'Bearer test-key');
        expect(captured.headers['x-test'], 'extra');
        expect(captured.headers['content-type'], contains('application/json'));
        expect(jsonDecode(captured.body), {
          'model': 'chat-model',
          'messages': [
            {'role': 'system', 'content': 'System ä'},
            {'role': 'user', 'content': 'User ö'},
          ],
        });
      },
    );

    test(
      'returns empty text for absent choices, message, or content',
      () async {
        var index = 0;
        final bodies = [
          <String, Object?>{},
          {
            'choices': [{}],
          },
          {
            'choices': [
              {'message': <String, Object?>{}},
            ],
          },
        ];
        final client = _TestClient(
          RecordingHttpClient((_) async => jsonResponse(bodies[index++])),
        );

        expect(await _chat(client), '');
        expect(await _chat(client), '');
        expect(await _chat(client), '');
      },
    );

    test('extracts a scalar compatible API error', () async {
      final client = _TestClient(
        RecordingHttpClient(
          (_) async => jsonResponse({'error': 'quota'}, statusCode: 429),
        ),
      );

      await expectLater(
        _chat(client),
        throwsA(
          isA<RemoteApiException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having(
                (error) => error.message,
                'message',
                'API error (429): quota',
              ),
        ),
      );
    });

    test('rejects malformed successful JSON', () async {
      final client = _TestClient(
        RecordingHttpClient((_) async => textResponse('{invalid')),
      );
      await expectLater(_chat(client), throwsFormatException);
    });
  });
}

void _registerModelTests() {
  group('OpenAiCompatibleClient.listModels', () {
    test('filters and sorts transcription model identifiers', () async {
      late http.Request captured;
      final client = _TestClient(
        RecordingHttpClient((request) async {
          captured = request as http.Request;
          return jsonResponse({
            'data': [
              {'id': 'whisper-z'},
              {'id': 'gpt-chat'},
              {'id': 'Gpt-4O-Transcribe'},
              {'id': ''},
              <String, Object?>{},
            ],
          });
        }),
      );

      final models = await client.listModels(forTranscription: true);

      expect(captured.method, 'GET');
      expect(captured.url, Uri.parse('https://example.test/v1/models'));
      expect(captured.headers['authorization'], 'Bearer test-key');
      expect(captured.headers['x-test'], 'extra');
      expect(models.map((model) => model.id), [
        'Gpt-4O-Transcribe',
        'whisper-z',
      ]);
    });

    test('blocks non-chat capability models and sorts remaining IDs', () async {
      const blocked = [
        'text-embed',
        'whisper-1',
        'new-transcribe',
        'tts-1',
        'audio-preview',
        'realtime-preview',
        'image-1',
        'moderation-1',
        'dall-e',
      ];
      final data = [
        ...blocked.map((id) => {'id': id}),
        {'id': 'z-chat'},
        {'id': 'A-chat'},
      ];
      final client = _TestClient(
        RecordingHttpClient((_) async => jsonResponse({'data': data})),
      );

      final models = await client.listModels(forTranscription: false);
      expect(models.map((model) => model.id), ['A-chat', 'z-chat']);
    });

    test('returns an empty list when data is absent', () async {
      final client = _TestClient(
        RecordingHttpClient((_) async => jsonResponse({})),
      );
      expect(await client.listModels(forTranscription: false), isEmpty);
    });

    test('surfaces a structured model-list error', () async {
      final client = _TestClient(
        RecordingHttpClient((_) async {
          return jsonResponse({
            'error': {'message': 'Denied'},
          }, statusCode: 403);
        }),
      );

      await expectLater(
        client.listModels(forTranscription: false),
        throwsA(
          isA<RemoteApiException>().having(
            (error) => error.message,
            'message',
            'Failed to fetch model list (403): Denied',
          ),
        ),
      );
    });
  });
}

void _registerTranscriptionSuccessTests() {
  group('OpenAiCompatibleClient.transcribeOpenAi', () {
    test('requests verbose Whisper output and maps valid segments', () async {
      final file = await _audioFile('voice.wav', [1, 2, 3]);
      late http.MultipartRequest captured;
      final client = _TestClient(
        RecordingHttpClient((request) async {
          captured = request as http.MultipartRequest;
          return jsonResponse({
            'text': ' Full transcript ',
            'segments': [
              {'start': 65.6, 'text': ' First '},
              {'start': null, 'text': 'Second'},
              {'start': 12, 'text': '   '},
            ],
          });
        }),
      );

      try {
        final result = await client.transcribe(
          file.path,
          languageCode: 'de',
          model: 'Whisper-1',
        );

        _expectMultipartBasics(captured, file.path);
        expect(captured.fields, {
          'model': 'Whisper-1',
          'response_format': 'verbose_json',
          'language': 'de',
        });
        expect(result.text, 'Full transcript');
        expect(result.segments.map((line) => line.time), ['1:06', '0:00']);
        expect(result.segments.map((line) => line.text), ['First', 'Second']);
      } finally {
        await file.parent.delete(recursive: true);
      }
    });

    test('requests plain JSON and creates a fallback segment', () async {
      final file = await _audioFile('voice.m4a', [4, 5]);
      late http.MultipartRequest captured;
      final client = _TestClient(
        RecordingHttpClient((request) async {
          captured = request as http.MultipartRequest;
          return jsonResponse({'text': ' Plain result '});
        }),
      );

      try {
        final result = await client.transcribe(
          file.path,
          languageCode: 'auto',
          model: 'gpt-4o-transcribe',
        );

        expect(captured.fields, {
          'model': 'gpt-4o-transcribe',
          'response_format': 'json',
        });
        expect(result.text, 'Plain result');
        expect(result.segments.single.time, '0:00');
        expect(result.segments.single.text, 'Plain result');
      } finally {
        await file.parent.delete(recursive: true);
      }
    });

    test('keeps segments empty when response text is empty', () async {
      final file = await _audioFile('voice.wav', [1]);
      final client = _TestClient(
        RecordingHttpClient((_) async => jsonResponse({'text': ' '})),
      );

      try {
        final result = await client.transcribe(file.path, model: 'gpt-audio');
        expect(result.text, '');
        expect(result.segments, isEmpty);
      } finally {
        await file.parent.delete(recursive: true);
      }
    });
  });
}

void _registerTranscriptionFailureTests() {
  group('OpenAiCompatibleClient.transcribeOpenAi failures', () {
    test('surfaces raw transcription errors with status', () async {
      final file = await _audioFile('voice.wav', [1]);
      final client = _TestClient(
        RecordingHttpClient(
          (_) async => textResponse('bad audio', statusCode: 400),
        ),
      );

      try {
        await expectLater(
          client.transcribe(file.path, model: 'whisper-1'),
          throwsA(
            isA<RemoteApiException>()
                .having((error) => error.statusCode, 'statusCode', 400)
                .having(
                  (error) => error.message,
                  'message',
                  'Transcription error (400): bad audio',
                ),
          ),
        );
      } finally {
        await file.parent.delete(recursive: true);
      }
    });

    test('rejects malformed successful transcription JSON', () async {
      final file = await _audioFile('voice.wav', [1]);
      final client = _TestClient(
        RecordingHttpClient((_) async => textResponse('not-json')),
      );

      try {
        await expectLater(
          client.transcribe(file.path, model: 'whisper-1'),
          throwsFormatException,
        );
      } finally {
        await file.parent.delete(recursive: true);
      }
    });
  });
}

Future<String> _chat(_TestClient client) {
  return client.chat(system: 'system', user: 'user', modelId: 'model');
}

void _expectMultipartBasics(http.MultipartRequest request, String path) {
  expect(request.method, 'POST');
  expect(
    request.url,
    Uri.parse('https://example.test/v1/audio/transcriptions'),
  );
  expect(request.headers['Authorization'], 'Bearer test-key');
  expect(request.files.single.field, 'file');
  expect(request.files.single.filename, File(path).uri.pathSegments.last);
  expect(request.files.single.length, 3);
}

Future<File> _audioFile(String name, List<int> bytes) async {
  final directory = await Directory.systemTemp.createTemp(
    'openai-client-test-',
  );
  return File('${directory.path}/$name').writeAsBytes(bytes, flush: true);
}

class _TestClient extends OpenAiCompatibleClient {
  _TestClient(http.Client httpClient)
    : super(apiKey: 'test-key', httpClient: httpClient);

  @override
  String get baseUrl => 'https://example.test/v1';

  @override
  Map<String, String> get extraHeaders => const {'X-Test': 'extra'};

  @override
  bool get supportsAudioTranscription => true;

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
    required String model,
  }) {
    return transcribeOpenAi(
      audioPath,
      languageCode: languageCode,
      model: model,
    );
  }
}
