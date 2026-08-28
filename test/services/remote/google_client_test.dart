import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/data/models/transcription_result.dart';
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';

void main() {
  _registerChatTests();
  _registerModelTests();
  _registerTranscriptionResponseTests();
  _registerTranscriptionLimitTests();
}

void _registerChatTests() {
  group('GoogleClient.chat', () {
    test('sends generateContent JSON and joins UTF-8 response parts', () async {
      late http.Request captured;
      final httpClient = RecordingHttpClient((request) async {
        captured = request as http.Request;
        return jsonResponse({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': ' Grüß '},
                  {'inline_data': 'ignored'},
                  {'text': 'dich '},
                ],
              },
            },
          ],
        });
      });
      final client = GoogleClient(apiKey: 'a key', httpClient: httpClient);

      final text = await client.chat(
        system: 'System ä',
        user: 'User ö',
        modelId: 'gemini-test',
      );

      expect(text, 'Grüß dich');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/v1beta/models/gemini-test:generateContent');
      expect(captured.url.queryParameters, {'key': 'a key'});
      expect(captured.headers['content-type'], contains('application/json'));
      expect(jsonDecode(captured.body), {
        'systemInstruction': {
          'parts': [
            {'text': 'System ä'},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'User ö'},
            ],
          },
        ],
      });
    });

    test('returns empty text for absent candidates or parts', () async {
      var index = 0;
      final bodies = [
        <String, Object?>{},
        {
          'candidates': [{}],
        },
      ];
      final client = GoogleClient(
        apiKey: 'key',
        httpClient: RecordingHttpClient((_) async {
          return jsonResponse(bodies[index++]);
        }),
      );

      expect(await _chat(client), '');
      expect(await _chat(client), '');
    });

    test('preserves a raw error body and status', () async {
      final client = GoogleClient(
        apiKey: 'key',
        httpClient: RecordingHttpClient(
          (_) async => textResponse('upstream unavailable', statusCode: 503),
        ),
      );

      await expectLater(
        _chat(client),
        throwsA(
          isA<RemoteApiException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having(
                (error) => error.message,
                'message',
                'Google error (503): upstream unavailable',
              ),
        ),
      );
    });

    test('rejects malformed successful JSON', () async {
      final client = GoogleClient(
        apiKey: 'key',
        httpClient: RecordingHttpClient((_) async => textResponse('not-json')),
      );
      await expectLater(_chat(client), throwsFormatException);
    });
  });
}

void _registerModelTests() {
  group('GoogleClient.listModels', () {
    test(
      'filters unsupported and non-Gemini models in provider order',
      () async {
        late http.Request captured;
        final client = GoogleClient(
          apiKey: 'key/value',
          httpClient: RecordingHttpClient((request) async {
            captured = request as http.Request;
            return jsonResponse({
              'models': [
                _googleModel('models/gemini-z', 'Gemini Z', [
                  'generateContent',
                ]),
                _googleModel('models/embedding-1', 'Embed', ['embedContent']),
                _googleModel('models/palm-chat', 'Palm', ['generateContent']),
                _googleModel('models/GEMINI-a', null, ['generateContent']),
              ],
            });
          }),
        );

        final models = await client.listModels(forTranscription: true);

        expect(captured.method, 'GET');
        expect(captured.url.path, '/v1beta/models');
        expect(captured.url.queryParameters, {
          'key': 'key/value',
          'pageSize': '200',
        });
        expect(models.map((model) => model.id), ['gemini-z', 'GEMINI-a']);
        expect(models.map((model) => model.label), ['Gemini Z', null]);
      },
    );

    test('uses an empty list when models are absent', () async {
      final client = GoogleClient(
        apiKey: 'key',
        httpClient: RecordingHttpClient((_) async => jsonResponse({})),
      );
      expect(await client.listModels(forTranscription: false), isEmpty);
    });
  });
}

void _registerTranscriptionResponseTests() {
  group('GoogleClient.transcribe', () {
    test(
      'embeds audio MIME, bytes, explicit language, and returns a segment',
      () async {
        await _withGoogleTranscription(
          fileName: 'voice.MP3',
          bytes: utf8.encode('audio bytes'),
          responseText: '  Überprüfung  ',
          languageCode: 'de',
          verify: (result, body) {
            final parts = _requestParts(body);
            expect(parts.first['text'], contains('language "de"'));
            expect(parts.last['inline_data'], {
              'mime_type': 'audio/mpeg',
              'data': base64Encode(utf8.encode('audio bytes')),
            });
            expect(result.text, 'Überprüfung');
            expect(result.segments.single.time, '0:00');
            expect(result.segments.single.text, 'Überprüfung');
          },
        );
      },
    );

    test(
      'uses the language-neutral prompt and no segment for empty text',
      () async {
        await _withGoogleTranscription(
          fileName: 'voice.wav',
          bytes: [1, 2, 3],
          responseText: '   ',
          languageCode: 'auto',
          verify: (result, body) {
            expect(
              _requestParts(body).first['text'],
              isNot(contains('language "')),
            );
            expect(result.text, '');
            expect(result.segments, isEmpty);
          },
        );
      },
    );
  });
}

void _registerTranscriptionLimitTests() {
  group('GoogleClient.transcribe limits', () {
    test(
      'rejects audio above the inline limit without an HTTP request',
      () async {
        final file = await _audioFile(
          'large.wav',
          List<int>.filled(14 * 1024 * 1024 + 1, 0),
        );
        final httpClient = RecordingHttpClient((_) async {
          fail('No request expected');
        });
        final client = GoogleClient(apiKey: 'key', httpClient: httpClient);

        try {
          await expectLater(
            client.transcribe(file.path, model: 'gemini-audio'),
            throwsA(
              isA<RemoteApiException>().having(
                (error) => error.message,
                'message',
                contains('Audio too large'),
              ),
            ),
          );
          expect(httpClient.requests, isEmpty);
        } finally {
          await file.parent.delete(recursive: true);
        }
      },
    );
  });
}

Future<String> _chat(GoogleClient client) {
  return client.chat(system: 'system', user: 'user', modelId: 'gemini');
}

Map<String, Object?> _googleModel(
  String name,
  String? displayName,
  List<String> methods,
) {
  final model = <String, Object?>{
    'name': name,
    'supportedGenerationMethods': methods,
  };
  if (displayName case final displayName?) {
    model['displayName'] = displayName;
  }
  return model;
}

Map<String, Object?> _candidateText(String text) {
  return {
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': text},
          ],
        },
      },
    ],
  };
}

List<Map<dynamic, dynamic>> _requestParts(Map<String, dynamic> body) {
  final contents = body['contents']! as List<dynamic>;
  final content = contents.single as Map<dynamic, dynamic>;
  return (content['parts']! as List<dynamic>).cast<Map<dynamic, dynamic>>();
}

Future<File> _audioFile(String name, List<int> bytes) async {
  final directory = await Directory.systemTemp.createTemp(
    'google-client-test-',
  );
  return File('${directory.path}/$name').writeAsBytes(bytes, flush: true);
}

Future<void> _withGoogleTranscription({
  required String fileName,
  required List<int> bytes,
  required String responseText,
  required String languageCode,
  required void Function(TranscriptionResult result, Map<String, dynamic> body)
  verify,
}) async {
  final file = await _audioFile(fileName, bytes);
  late Map<String, dynamic> requestBody;
  final client = GoogleClient(
    apiKey: 'key',
    httpClient: RecordingHttpClient((request) async {
      requestBody =
          jsonDecode((request as http.Request).body) as Map<String, dynamic>;
      return jsonResponse(_candidateText(responseText));
    }),
  );

  try {
    final result = await client.transcribe(
      file.path,
      languageCode: languageCode,
      model: 'gemini-audio',
    );
    verify(result, requestBody);
  } finally {
    await file.parent.delete(recursive: true);
  }
}
