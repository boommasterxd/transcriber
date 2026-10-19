import 'dart:convert';
import 'dart:typed_data';

Map<String, String> parseGitFiles(Uint8List data, List<String> paths) {
  final files = <String, String>{};
  var offset = 0;
  for (final path in paths) {
    final headerEnd = data.indexOf(10, offset);
    if (headerEnd < offset || headerEnd - offset > 128) {
      throw const FormatException('Incomplete Git object header.');
    }
    final header = ascii.decode(Uint8List.sublistView(data, offset, headerEnd));
    final match = RegExp(
      r'^(?:[a-f0-9]{40}|[a-f0-9]{64}) blob ([0-9]+)$',
    ).firstMatch(header);
    final size = int.tryParse(match?.group(1) ?? '');
    if (size == null || size > 2 * 1024 * 1024) {
      throw const FormatException('Invalid or oversized Git source object.');
    }
    final start = headerEnd + 1;
    final end = start + size;
    if (end >= data.length || data[end] != 10 || files.containsKey(path)) {
      throw const FormatException('Incomplete or duplicate Git source object.');
    }
    files[path] = utf8.decode(Uint8List.sublistView(data, start, end));
    offset = end + 1;
  }
  if (offset != data.length) {
    throw const FormatException('Unexpected Git source output.');
  }
  return files;
}
