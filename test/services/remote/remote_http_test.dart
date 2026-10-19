import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/services/remote/remote_http.dart';
import 'package:transcriber/services/service_exceptions.dart';

void main() {
  _registerTimeoutTests();
  _registerErrorMessageTests();
  _registerResponseValidationTests();
  _registerBoundedBodyTests();
  _registerAudioValidationTests();
}

void _registerBoundedBodyTests() {
  group('readRemoteResponseBody', () {
    test('reads valid streamed UTF-8', () async {
      final response = http.StreamedResponse(
        Stream.value([0x47, 0x72, 0xc3, 0xbc, 0xc3, 0x9f, 0x65]),
        200,
      );

      expect(await readRemoteResponseBody(response), 'Grüße');
    });

    test('rejects oversized and malformed streamed responses', () async {
      final oversized = http.StreamedResponse(
        Stream.value(List<int>.filled(maxRemoteResponseBytes + 1, 0)),
        200,
      );
      final malformed = http.StreamedResponse(Stream.value([0xff]), 200);

      await expectLater(
        readRemoteResponseBody(oversized),
        throwsA(isA<RemoteApiException>()),
      );
      await expectLater(
        readRemoteResponseBody(malformed),
        throwsA(isA<RemoteApiException>()),
      );
    });
  });
}

void _registerAudioValidationTests() {
  test('validateRemoteAudioFile rejects empty provider uploads', () async {
    final directory = await Directory.systemTemp.createTemp('remote-empty-');
    final file = await File('${directory.path}/empty.wav').create();
    try {
      await expectLater(
        validateRemoteAudioFile(file),
        throwsA(isA<RemoteApiException>()),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

void _registerTimeoutTests() {
  group('guardTimeout', () {
    test('returns a value completed before the deadline', () async {
      expect(await guardTimeout(Future.value('done'), Duration.zero), 'done');
    });

    test('converts a timeout to the stable remote API exception', () async {
      final pending = Completer<String>();

      await expectLater(
        guardTimeout(pending.future, Duration.zero),
        throwsA(
          isA<RemoteApiException>().having(
            (error) => error.message,
            'message',
            contains('Request timed out'),
          ),
        ),
      );
    });
  });

  test('sendRemoteRequest times out while a response body stalls', () async {
    final stalledBody = StreamController<List<int>>();
    addTearDown(stalledBody.close);
    final client = _ResponseClient(
      http.StreamedResponse(stalledBody.stream, 200),
    );

    await expectLater(
      sendRemoteRequest(
        client,
        http.Request('GET', Uri.parse('https://example.test')),
        timeout: Duration.zero,
      ),
      throwsA(
        isA<RemoteApiException>().having(
          (error) => error.message,
          'message',
          contains('Request timed out'),
        ),
      ),
    );
  });
}

final class _ResponseClient extends http.BaseClient {
  _ResponseClient(this.response);

  final http.StreamedResponse response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      response;
}

void _registerErrorMessageTests() {
  group('remoteErrorMessage', () {
    test('extracts a conventional provider error message', () {
      expect(
        remoteErrorMessage('{"error":{"message":"Invalid key"}}'),
        'Invalid key',
      );
    });

    test('preserves a scalar OpenAI-compatible error when requested', () {
      expect(
        remoteErrorMessage('{"error":"Unavailable"}', preferScalarError: true),
        'Unavailable',
      );
    });

    test('uses a safe fallback for malformed bodies', () {
      expect(
        remoteErrorMessage('not-json'),
        'The provider returned an invalid error response.',
      );
    });

    test('falls back when decoded JSON is not an object', () {
      expect(
        remoteErrorMessage('["error"]'),
        'The provider returned an invalid error response.',
      );
    });

    test('uses a safe fallback for a scalar error by default', () {
      expect(
        remoteErrorMessage('{"error":"Unavailable"}'),
        'The provider returned an error.',
      );
    });

    test('uses the body when a structured error has no message', () {
      const body = '{"error":{"code":"invalid"}}';
      expect(remoteErrorMessage(body), 'The provider returned an error.');
    });

    test('redacts secrets from a structured provider message', () {
      expect(
        remoteErrorMessage(
          '{"error":{"message":"token=secret-key"}}',
          secret: 'secret-key',
        ),
        '[REDACTED]',
      );
    });
  });
}

void _registerResponseValidationTests() {
  group('validateRemoteResponse', () {
    test('accepts a successful response', () {
      expect(
        () => validateRemoteResponse(
          statusCode: 200,
          body: '{}',
          errorLabel: 'Provider error',
        ),
        returnsNormally,
      );
    });

    test('accepts any successful HTTP status', () {
      expect(
        () => validateRemoteResponse(
          statusCode: 201,
          body: '{}',
          errorLabel: 'Provider error',
        ),
        returnsNormally,
      );
    });

    test('throws the existing labeled exception shape', () {
      expect(
        () => validateRemoteResponse(
          statusCode: 401,
          body: '{"error":{"message":"Invalid key"}}',
          errorLabel: 'Provider error',
        ),
        throwsA(
          isA<RemoteApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having(
                (error) => error.message,
                'message',
                'Provider error (401): Invalid key',
              ),
        ),
      );
    });

    test('includes a scalar error for compatible providers', () {
      expect(
        () => validateRemoteResponse(
          statusCode: 429,
          body: '{"error":"Rate limited"}',
          errorLabel: 'API error',
          preferScalarError: true,
        ),
        throwsA(
          isA<RemoteApiException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having(
                (error) => error.message,
                'message',
                'API error (429): Rate limited',
              ),
        ),
      );
    });
  });
}
