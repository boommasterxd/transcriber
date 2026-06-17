import 'package:path/path.dart' as p;

/// Best-effort audio MIME type from a file extension.
String audioMimeType(String path) {
  switch (p.extension(path).toLowerCase()) {
    case '.wav':
      return 'audio/wav';
    case '.mp3':
      return 'audio/mpeg';
    case '.m4a':
    case '.mp4':
      return 'audio/mp4';
    case '.aac':
      return 'audio/aac';
    case '.ogg':
    case '.opus':
      return 'audio/ogg';
    case '.flac':
      return 'audio/flac';
    case '.webm':
      return 'audio/webm';
    default:
      return 'application/octet-stream';
  }
}
