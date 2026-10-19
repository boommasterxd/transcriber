import 'dart:io';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';

typedef AudioTranscription =
    Future<Object?> Function(String audioPath, RecordingHttpClient httpClient);
typedef AudioTestAction = Future<void> Function(File file);

RecordingHttpClient scriptedHttpClient(List<http.StreamedResponse> responses) {
  var index = 0;
  return RecordingHttpClient((_) async => responses[index++]);
}

void expectCatalogRequests(
  RecordingHttpClient httpClient, {
  required String expectedPath,
  required String headerName,
  required String headerValue,
  String? expectedQueryKey,
}) {
  expect(httpClient.requests, hasLength(3));
  for (final request in httpClient.requests) {
    expect(request.url.path, expectedPath);
    expect(request.headers[headerName], headerValue);
    if (expectedQueryKey != null) {
      expect(request.url.queryParameters.keys, everyElement(expectedQueryKey));
    }
  }
}

Future<void> withTemporaryAudio({
  required String prefix,
  required AudioTestAction action,
  String fileName = 'voice.wav',
  List<int> bytes = const [1],
}) {
  return _withAudioDirectory(
    prefix: prefix,
    createFile: (directory) =>
        File('${directory.path}/$fileName').writeAsBytes(bytes),
    action: action,
  );
}

Future<void> withOversizedAudio({
  required String prefix,
  required AudioTestAction action,
  String fileName = 'voice.wav',
}) {
  return _withAudioDirectory(
    prefix: prefix,
    createFile: (directory) => _createOversizedAudio(directory, fileName),
    action: action,
  );
}

Future<void> expectOversizedAudioRejected({
  required String prefix,
  required AudioTranscription transcribe,
}) async {
  await withOversizedAudio(
    prefix: prefix,
    action: (file) async {
      final httpClient = RecordingHttpClient((_) async => jsonResponse({}));
      await expectLater(
        transcribe(file.path, httpClient),
        throwsA(
          isA<RemoteApiException>().having(
            (error) => error.message,
            'message',
            'The audio file is too large.',
          ),
        ),
      );
      expect(httpClient.requests, isEmpty);
    },
  );
}

List<http.StreamedResponse> googleTranscriptionFailureResponses({
  required String session,
  required String fileState,
  required Object failureBody,
}) {
  final failureResponse = failureBody is String
      ? textResponse(failureBody)
      : jsonResponse(failureBody);
  return [
    jsonResponse(
      {},
      headers: {'x-goog-upload-url': 'https://upload.test/$session'},
    ),
    jsonResponse({
      'file': {
        'name': 'files/$session',
        'uri': 'https://files.test/$session',
        'state': fileState,
      },
    }),
    failureResponse,
    jsonResponse({}),
  ];
}

Future<void> _withAudioDirectory({
  required String prefix,
  required Future<File> Function(Directory directory) createFile,
  required AudioTestAction action,
}) async {
  final directory = await Directory.systemTemp.createTemp(prefix);
  final file = await createFile(directory);
  try {
    await action(file);
  } finally {
    await directory.delete(recursive: true);
  }
}

Future<File> _createOversizedAudio(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  final handle = await file.open(mode: FileMode.write);
  await handle.setPosition(100 * 1024 * 1024 + 1);
  await handle.writeByte(0);
  await handle.close();
  return file;
}
