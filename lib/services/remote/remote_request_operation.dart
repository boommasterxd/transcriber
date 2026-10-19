import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../service_exceptions.dart';

/// Owns the deadline and response subscription for a single provider request.
final class RemoteRequestOperation {
  RemoteRequestOperation(this.client, this.request, this.maxResponseBytes);

  final http.Client client;
  final http.BaseRequest request;
  final int maxResponseBytes;
  final _abort = Completer<void>();
  final _result = Completer<http.Response>();
  final _bytes = BytesBuilder(copy: false);
  StreamSubscription<List<int>>? _subscription;

  Future<http.Response> run(Duration timeout) async {
    final timer = Timer(timeout, () {
      _fail(
        const RemoteApiException(
          'Request timed out - the provider did not respond in time. '
          'Check your connection and try again.',
        ),
      );
    });
    unawaited(_send());
    try {
      return await _result.future;
    } finally {
      timer.cancel();
      if (!_abort.isCompleted) _abort.complete();
    }
  }

  Future<void> _send() async {
    try {
      final response = await client.send(
        _abortableRequest(request, _abort.future),
      );
      if (_result.isCompleted) {
        _cancel(response.stream.listen(null, onError: (Object _) {}));
        return;
      }
      _subscription = response.stream.listen(
        _add,
        onError: (Object error, StackTrace stack) => _fail(error, stack),
        onDone: () => _complete(response),
      );
    } catch (error, stack) {
      _fail(error, stack);
    }
  }

  void _add(List<int> chunk) {
    if (_result.isCompleted) return;
    if (_bytes.length + chunk.length > maxResponseBytes) {
      _fail(const RemoteApiException('The provider response was too large.'));
      return;
    }
    _bytes.add(chunk);
  }

  void _complete(http.StreamedResponse response) {
    if (_result.isCompleted) return;
    _result.complete(
      http.Response.bytes(
        _bytes.takeBytes(),
        response.statusCode,
        headers: response.headers,
      ),
    );
  }

  void _fail(Object error, [StackTrace? stack]) {
    if (_result.isCompleted) return;
    _abort.complete();
    final subscription = _subscription;
    if (subscription != null) _cancel(subscription);
    _result.completeError(error, stack);
  }

  void _cancel(StreamSubscription<List<int>> subscription) {
    // A broken injected stream must not delay the deadline indefinitely.
    unawaited(
      subscription
          .cancel()
          .timeout(const Duration(seconds: 1))
          .catchError((Object _) {}),
    );
  }
}

http.BaseRequest _abortableRequest(
  http.BaseRequest request,
  Future<void> abort,
) {
  final http.BaseRequest result;
  if (request is http.Request) {
    result = http.AbortableRequest(
      request.method,
      request.url,
      abortTrigger: abort,
    )..bodyBytes = request.bodyBytes;
  } else if (request is http.MultipartRequest) {
    result =
        http.AbortableMultipartRequest(
            request.method,
            request.url,
            abortTrigger: abort,
          )
          ..fields.addAll(request.fields)
          ..files.addAll(request.files);
  } else {
    result = _AbortableStreamRequest(request, abort);
  }
  return result
    ..headers.addAll(request.headers)
    ..followRedirects = request.followRedirects
    ..maxRedirects = request.maxRedirects
    ..persistentConnection = request.persistentConnection;
}

final class _AbortableStreamRequest extends http.BaseRequest
    with http.Abortable {
  _AbortableStreamRequest(this.request, this.abortTrigger)
    : super(request.method, request.url) {
    contentLength = request.contentLength;
  }

  final http.BaseRequest request;
  @override
  final Future<void> abortTrigger;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return request.finalize();
  }
}
