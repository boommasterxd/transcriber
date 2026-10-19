import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:transcriber/services/remote/remote_http.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';

void main() {
  _registerDeadlineTests();
  _registerSuccessfulResponseTest();
  _registerOversizedResponseTest();
  _registerFailureTests();
}

void _registerDeadlineTests() {
  test('aborts a request stalled before response headers', () async {
    final client = _AbortAwareClient();
    await _expectDeadline(client, http.Request('GET', _url));
    await client.aborted.future;
    expect(client.closeCalls, 0);
  });

  test('cancels body consumption at the deadline', () async {
    final cancelled = Completer<void>();
    final body = StreamController<List<int>>(onCancel: cancelled.complete);
    final client = RecordingHttpClient((_) async {
      return http.StreamedResponse(body.stream, 200);
    });
    await _expectDeadline(client, http.Request('GET', _url));
    await cancelled.future;
    expect(body.hasListener, isFalse);
    await body.close();
  });

  test('aborts stalled upload and cancels its input stream', () async {
    final cancelled = Completer<void>();
    final body = StreamController<List<int>>(onCancel: cancelled.complete);
    final request = _UploadRequest(body.stream)..contentLength = 1;
    final client = _AbortAwareClient(consumeUpload: true);
    await _expectDeadline(client, request);
    await cancelled.future;
    expect(body.hasListener, isFalse);
    expect(client.closeCalls, 0);
    await body.close();
  });

  test('cancels a response arriving after its deadline', () async {
    final headers = Completer<http.StreamedResponse>();
    final cancelled = Completer<void>();
    final body = StreamController<List<int>>(onCancel: cancelled.complete);
    final client = RecordingHttpClient((_) => headers.future);
    await _expectDeadline(client, http.Request('GET', _url));
    headers.complete(http.StreamedResponse(body.stream, 200));
    await cancelled.future;
    await body.close();
  });

  test('a stalled cancellation cannot hold the timeout result', () async {
    final cleanup = Completer<void>();
    final body = StreamController<List<int>>(onCancel: () => cleanup.future);
    final client = RecordingHttpClient((_) async {
      return http.StreamedResponse(body.stream, 200);
    });
    await _expectDeadline(client, http.Request('GET', _url));
    expect(body.hasListener, isFalse);
    cleanup.complete();
    await body.close();
  });
}

void _registerSuccessfulResponseTest() {
  test(
    'successful response preserves payload, headers and request options',
    () async {
      final client = RecordingHttpClient((request) async {
        expect(request, isA<http.Abortable>());
        expect(request.headers['authorization'], 'Bearer test');
        expect(request.followRedirects, isFalse);
        expect(request.maxRedirects, 2);
        expect(request.persistentConnection, isFalse);
        expect((request as http.Request).body, 'payload');
        return textResponse(
          'Grüße',
          statusCode: 201,
          headers: {'x-test': 'ok'},
        );
      });
      final response = await sendRemoteRequest(
        client,
        http.Request('POST', _url)
          ..headers['authorization'] = 'Bearer test'
          ..body = 'payload'
          ..followRedirects = false
          ..maxRedirects = 2
          ..persistentConnection = false,
        timeout: Duration.zero,
      );
      expect(response.body, 'Grüße');
      expect(response.statusCode, 201);
      expect(response.headers['x-test'], 'ok');
    },
  );
}

void _registerOversizedResponseTest() {
  test('oversized response aborts transport and cancels consumption', () async {
    final client = _OversizedClient();
    await expectLater(
      sendRemoteRequest(
        client,
        http.Request('GET', _url),
        timeout: const Duration(seconds: 1),
      ),
      throwsA(isA<RemoteApiException>()),
    );
    await client.aborted.future;
    expect(client.cancelled, isTrue);
  });
}

void _registerFailureTests() {
  test('preserves a failure before response headers', () async {
    final failure = http.ClientException('connection failed');
    final client = MockClient((_) async => throw failure);
    await expectLater(
      sendRemoteRequest(
        client,
        http.Request('GET', _url),
        timeout: Duration.zero,
      ),
      throwsA(same(failure)),
    );
  });

  test('preserves a response stream error and cancels consumption', () async {
    final failure = http.ClientException('connection interrupted');
    final body = StreamController<List<int>>();
    final client = RecordingHttpClient(
      (_) async => http.StreamedResponse(body.stream, 200),
    );
    final result = sendRemoteRequest(
      client,
      http.Request('GET', _url),
      timeout: Duration.zero,
    );
    body.addError(failure);
    await expectLater(result, throwsA(same(failure)));
    expect(body.hasListener, isFalse);
    await body.close();
  });

  test('a failed cancellation does not replace the deadline error', () async {
    final body = StreamController<List<int>>(
      onCancel: () async => throw StateError('cleanup failed'),
    );
    final client = RecordingHttpClient(
      (_) async => http.StreamedResponse(body.stream, 200),
    );
    await _expectDeadline(client, http.Request('GET', _url));
    expect(body.hasListener, isFalse);
    await body.close();
  });
}

final _url = Uri.parse('https://example.test');

Future<void> _expectDeadline(
  http.Client client,
  http.BaseRequest request,
) async {
  await expectLater(
    sendRemoteRequest(client, request, timeout: Duration.zero),
    throwsA(
      isA<RemoteApiException>().having(
        (error) => error.message,
        'message',
        contains('Request timed out'),
      ),
    ),
  );
}

final class _AbortAwareClient extends http.BaseClient {
  _AbortAwareClient({this.consumeUpload = false});

  final bool consumeUpload;
  final aborted = Completer<void>();
  int closeCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final result = Completer<http.StreamedResponse>();
    final subscription = consumeUpload
        ? request.finalize().listen((_) {})
        : null;
    (request as http.Abortable).abortTrigger!.then((_) async {
      await subscription?.cancel();
      aborted.complete();
      result.completeError(http.RequestAbortedException(request.url));
    });
    return result.future;
  }

  @override
  void close() => closeCalls++;
}

final class _UploadRequest extends http.BaseRequest {
  _UploadRequest(this.body) : super('POST', _url);

  final Stream<List<int>> body;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(body);
  }
}

final class _OversizedClient extends http.BaseClient {
  final aborted = Completer<void>();
  bool cancelled = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    (request as http.Abortable).abortTrigger!.then((_) => aborted.complete());
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    body.add(List.filled(maxRemoteResponseBytes + 1, 0));
    unawaited(body.close());
    return http.StreamedResponse(body.stream, 200);
  }
}
