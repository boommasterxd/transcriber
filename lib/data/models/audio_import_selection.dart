/// A selected audio document already copied into the app's private cache.
class AudioImportSelection {
  const AudioImportSelection({required this.path, required this.fileName});

  final String path;
  final String fileName;
}
