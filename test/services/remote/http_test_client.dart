import 'dart:convert';

import 'package:http/http.dart' as http;

typedef RequestHandler = Future<http.StreamedResponse> Function(
  http.BaseRequest request,
);

class RecordingHttpClient extends http.BaseClient {
  RecordingHttpClient(this._handler, {this.readBody});

  final RequestHandler _handler;
  final Future<void> Function(http.ByteStream)? readBody;
  final List<http.BaseRequest> requests = [];
  int closeCalls = 0;

  @override
  void close() => closeCalls++;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = await _handler(request);
    final body = request.finalize();
    await (readBody?.call(body) ?? body.drain<void>());
    return response;
  }
}

http.StreamedResponse jsonResponse(
  Object body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  return textResponse(
    jsonEncode(body),
    statusCode: statusCode,
    headers: headers,
  );
}

http.StreamedResponse textResponse(
  String body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
  );
}
