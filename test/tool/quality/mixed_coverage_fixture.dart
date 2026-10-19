import 'dart:async';
import 'dart:convert';
import 'dart:io';

final class MixedCoverageFixture {
  MixedCoverageFixture._(this.root, this.flutterRoot);

  final Directory root;
  final String flutterRoot;

  static Future<MixedCoverageFixture> create(String source) async {
    final original = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(await original.readAsString()) as Map<String, dynamic>;
    final root = await Directory.systemTemp.createTemp(
      'mixed-runtime-coverage-',
    );
    for (final item
        in (config['packages'] as List).cast<Map<String, dynamic>>()) {
      item['rootUri'] = original.uri
          .resolve(item['rootUri'] as String)
          .toString();
      if (item['name'] == 'transcriber') {
        item['name'] = 'mixed_coverage_fixture';
        item['rootUri'] = root.uri.toString();
      }
    }
    final fixture = MixedCoverageFixture._(
      root,
      Uri.parse(config['flutterRoot'] as String).toFilePath(),
    );
    await fixture._write('pubspec.yaml', '''
name: mixed_coverage_fixture
environment:
  sdk: '>=3.12.0 <4.0.0'
dev_dependencies:
  test: any
  flutter_test:
    sdk: flutter
''');
    await fixture._write('lib/choice.dart', source);
    for (final runtime in ['dart', 'flutter']) {
      final testLibrary = runtime == 'dart'
          ? 'test/test.dart'
          : 'flutter_test/flutter_test.dart';
      await fixture._write('test/${runtime}_choice_test.dart', '''
import 'package:$testLibrary';
import 'package:mixed_coverage_fixture/choice.dart';
void main() {
  test('runtime branch', () => expect(choice(${runtime == 'dart'}), ${runtime == 'dart' ? 1 : 2}));
}
''');
    }
    await fixture._write('.dart_tool/package_config.json', jsonEncode(config));
    return fixture;
  }

  Future<List<String>> collect(String runtime) async {
    final isFlutter = runtime == 'flutter';
    final process = await Process.start(
      '$flutterRoot/bin/${isFlutter ? 'flutter' : 'dart'}',
      [
        'test',
        if (isFlutter) ...['--no-pub', '--coverage'],
        '--coverage-path=coverage/$runtime/lcov.info',
        '--branch-coverage',
        'test/${runtime}_choice_test.dart',
      ],
      workingDirectory: root.path,
    );
    final timer = Timer(const Duration(minutes: 1), () => process.kill());
    try {
      final results = await Future.wait<Object>([
        process.stdout.transform(utf8.decoder).join(),
        process.stderr.transform(utf8.decoder).join(),
        process.exitCode,
      ]);
      if (results[2] != 0) {
        throw StateError(
          'Coverage fixture $runtime failed: ${results[0]} ${results[1]}',
        );
      }
      return await File(
        '${root.path}/coverage/$runtime/lcov.info',
      ).readAsLines();
    } finally {
      timer.cancel();
    }
  }

  Future<void> dispose() => root.delete(recursive: true);

  Future<void> _write(String path, String contents) async {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }
}
