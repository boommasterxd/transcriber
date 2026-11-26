import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:transcriber/services/remote/remote_http.dart';
import 'package:transcriber/services/service_exceptions.dart';

void main() {
  _registerDeadlineTests();
  _registerOversizedResponseTest();
}

void _registerDeadlineTests() {
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
