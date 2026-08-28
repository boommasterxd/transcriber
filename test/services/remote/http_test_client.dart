import 'dart:convert';

import 'package:http/http.dart' as http;

typedef RequestHandler =
    Future<http.StreamedResponse> Function(http.BaseRequest request);

class RecordingHttpClient extends http.BaseClient {
  RecordingHttpClient(this._handler);

  final RequestHandler _handler;
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = _handler(request);
    await request.finalize().drain<void>();
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
