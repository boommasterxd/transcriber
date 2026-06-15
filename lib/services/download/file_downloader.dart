import 'dart:io';

import 'package:http/http.dart' as http;

/// Streams a file to disk with progress, supporting an optional bearer token
/// (used for gated Hugging Face model artifacts). Resilient to interruptions:
/// downloads to a `.part` file and renames on success.
class FileDownloader {
  const FileDownloader();

  Future<void> download(
    String url,
    String destinationPath, {
    String? bearerToken,
    void Function(double progress)? onProgress,
  }) async {
    final dest = File(destinationPath);
    if (await dest.exists()) return; // already present

    final part = File('$destinationPath.part');
    if (await part.exists()) await part.delete();

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      if (bearerToken != null && bearerToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $bearerToken';
      }
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw HttpException('Download fehlgeschlagen (${response.statusCode}) für $url');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = part.openWrite();
      await response.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }).asFuture<void>();
      await sink.flush();
      await sink.close();
      await part.rename(destinationPath);
      onProgress?.call(1.0);
    } finally {
      client.close();
    }
  }
}
