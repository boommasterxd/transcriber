import 'dart:io';

final class CoverageFixture {
  CoverageFixture._(this.directory, this.sources);

  factory CoverageFixture.create(Map<String, String> files) {
    final directory = Directory.systemTemp.createTempSync('coverage-checker-');
    final sources = <String, String>{};
    for (final entry in files.entries) {
      final relativePath = 'lib/${entry.key}';
      final file = File('${directory.path}/$relativePath');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
      sources[file.absolute.path] = relativePath;
    }
    return CoverageFixture._(directory, sources);
  }

  final Directory directory;
  final Map<String, String> sources;

  String path(String name) => File('${directory.path}/lib/$name').absolute.path;

  List<String> record(String name, Iterable<String> entries) => [
    'SF:${path(name)}',
    ...entries,
    'end_of_record',
  ];

  int lineOf(String name, String text) {
    final lines = File(path(name)).readAsLinesSync();
    final index = lines.indexWhere((line) => line.contains(text));
    if (index < 0) throw StateError('Missing source text: $text');
    return index + 1;
  }

  void dispose() => directory.deleteSync(recursive: true);
}
