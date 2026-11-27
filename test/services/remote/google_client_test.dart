import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/data/catalog/remote_catalog.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

void main() {
  _registerSummaryTest();
  _registerTranscriptionTest();
  _registerMultimodalTranscriptionTest();
  _registerProviderErrorTest();
}

void _registerSummaryTest() {
  test(
    'uses generateContent for summaries with header authentication',
    _testSummary,
  );
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
    modelId: RemoteCatalog.chatDefault(RemoteProviderId.google),
  );
  final captured = httpClient.requests.single as http.Request;

  expect(result, 'summary');
  expect(captured.url.path, '/v1beta/models/gemini-3.8-flash:generateContent');
  expect(captured.headers['x-goog-api-key'], 'secret-key');
  expect(captured.url.queryParameters, isEmpty);
  expect(jsonDecode(captured.body), {
    'store': false,
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
      final deletionStarted = Completer<void>();
      final deletionBody = StreamController<List<int>>(
        onListen: deletionStarted.complete,
      );
      final httpClient = scriptedHttpClient([
        jsonResponse(
          {},
          headers: {'x-goog-upload-url': googleUploadUrl('session')},
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
        http.StreamedResponse(deletionBody.stream, 200),
      ]);
      final client = http.runWithClient(
        () => GoogleClient(apiKey: 'secret-key'),
        () => httpClient,
      );
      var resultReturned = false;
      final pending = client
          .transcribe(file.path, modelId: modelId, languageCode: 'de')
          .whenComplete(() {
            client.close();
            resultReturned = true;
          });
      try {
        await deletionStarted.future;
        await Future<void>(() {});
        expect(resultReturned, isTrue);
        expect(httpClient.closeCalls, 0);
      } finally {
        await deletionBody.close();
      }
      final result = await pending;
      await Future<void>(() {});
      expect(httpClient.closeCalls, 1);
      _expectTranscriptionRequests(
        httpClient.requests,
        modelId,
        expectedMimeType,
      );
      expect(result.text, 'Transcript');
      expect(result.segments.single.text, 'Transcript');
    },
  );
}

void _expectTranscriptionRequests(
  List<http.BaseRequest> requests,
  String modelId,
  String expectedMimeType,
) {
  expect(requests, hasLength(4));
  expect(requests[0].url.path, '/upload/v1beta/files');
  expect(
    requests[0].headers['X-Goog-Upload-Header-Content-Type'],
    expectedMimeType,
  );
  expect(requests[1].url.toString(), googleUploadUrl('session'));
  expect(requests[1].headers['Content-Type'], expectedMimeType);
  expect(requests[2].url.path, '/v1beta/interactions');
  expect(requests[3].method, 'DELETE');
  for (final request in requests) {
    final uploadsBytes = request.url.queryParameters.containsKey('upload_id');
    expect(request.url.queryParameters.containsKey('key'), isFalse);
    expect(
      request.headers['x-goog-api-key'],
      uploadsBytes ? isNull : 'secret-key',
    );
    expect(request.followRedirects, isFalse);
  }
  final interaction =
      jsonDecode((requests[2] as http.Request).body) as Map<String, dynamic>;
  expect(interaction['model'], modelId);
  expect(interaction['store'], isFalse);
  expect((interaction['input'] as List).single['type'], 'audio');
  expect((interaction['input'] as List).single['mime_type'], expectedMimeType);
  expect(interaction['generation_config']['transcription_config'], {
    'mode': {'type': 'smart'},
    'language_codes': ['de-DE'],
  });
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
          headers: {'x-goog-upload-url': googleUploadUrl('multimodal')},
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
      final interaction = jsonDecode(
        (httpClient.requests[2] as http.Request).body,
      ) as Map<String, dynamic>;
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
          headers: {'x-goog-upload-url': googleUploadUrl('error')},
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
