import 'dart:io';

/// Streams a stable app copy without relying on a source length sampled before opening it.
Future<void> copyAudioWithinLimit(
  File source,
  File target,
  int maximumBytes,
) async {
  final output = await target.open(mode: FileMode.write);
  try {
    var written = 0;
    await for (final bytes in source.openRead()) {
      written += bytes.length;
      if (written > maximumBytes) {
        throw const FileSystemException('Audio file size is not supported');
      }
      await output.writeFrom(bytes);
    }
    if (written == 0) {
      throw const FileSystemException('Audio file is empty');
    }
    await output.flush();
  } finally {
    await output.close();
  }
}
