import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/remote/remote_http.dart';
import 'package:transcriber/services/service_exceptions.dart';

void main() {
  _registerTimeoutTests();
  _registerErrorMessageTests();
  _registerResponseValidationTests();
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

    test('falls back to the original malformed body', () {
      expect(remoteErrorMessage('not-json'), 'not-json');
    });

    test('falls back when decoded JSON is not an object', () {
      expect(remoteErrorMessage('["error"]'), '["error"]');
    });

    test('preserves the body for a scalar error by default', () {
      const body = '{"error":"Unavailable"}';
      expect(remoteErrorMessage(body), body);
    });

    test('uses the body when a structured error has no message', () {
      const body = '{"error":{"code":"invalid"}}';
      expect(remoteErrorMessage(body), body);
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
