import 'dart:convert';

import 'package:http/http.dart' as http;

typedef RequestHandler =
    Future<http.StreamedResponse> Function(http.BaseRequest request);

class RecordingHttpClient extends http.BaseClient {
  RecordingHttpClient(this._handler);

  final RequestHandler _handler;
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return _handler(request);
  }
}

http.StreamedResponse jsonResponse(Object body, {int statusCode = 200}) {
  return textResponse(jsonEncode(body), statusCode: statusCode);
}

http.StreamedResponse textResponse(String body, {int statusCode = 200}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
