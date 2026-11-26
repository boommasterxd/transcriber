import 'dart:io';

import 'package:http/http.dart' as http;

import 'http_test_client.dart';

typedef AudioTestAction = Future<void> Function(File file);

RecordingHttpClient scriptedHttpClient(List<http.StreamedResponse> responses) {
  var index = 0;
  return RecordingHttpClient((_) async => responses[index++]);
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

String googleUploadUrl(String session) =>
    'https://generativelanguage.googleapis.com/upload/v1beta/files'
    '?upload_id=$session&upload_protocol=resumable';

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
