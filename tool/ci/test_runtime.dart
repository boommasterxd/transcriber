import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as path;

import 'selection_graph.dart';

final class TestRuntimes {
  TestRuntimes(this.dart, this.flutter, this.dartSources, this.flutterSources);

  final List<String> dart;
  final List<String> flutter;
  final Set<String> dartSources;
  final Set<String> flutterSources;

  static Future<TestRuntimes> classify(String root, List<String> tests) async {
    if (tests.isEmpty ||
        tests.toSet().length != tests.length ||
        tests.any(
          (file) =>
              !file.startsWith('test/') ||
              !file.endsWith('_test.dart') ||
              path.posix.normalize(file) != file,
        )) {
      throw const FormatException('Expected a nonempty unique test inventory.');
    }
    final sources = _RuntimeSources(root);
    final dart = <String>[];
    final flutter = <String>[];
    final dartSources = <String>{};
    final flutterSources = <String>{};
    for (final test in tests) {
      final source = await sources.read(test);
      final context = await sources.context(test);
      if (source.dartMarker && !context.flutter) {
        dart.add(test);
        dartSources.addAll(context.production);
      } else {
        flutter.add(test);
        flutterSources.addAll(context.production);
      }
    }
    return TestRuntimes(dart, flutter, dartSources, flutterSources);
  }
}

List<String> discoverTests(String root) {
  final directory = Directory('$root/test');
  if (!directory.existsSync()) {
    throw const FormatException('The test inventory is missing.');
  }
  final entries = directory.listSync(recursive: true, followLinks: false);
  if (entries.any((entry) => entry is Link)) {
    throw const FormatException('The test inventory contains symbolic links.');
  }
  return entries
      .whereType<File>()
      .where((file) => file.path.endsWith('_test.dart'))
      .map((file) => path.relative(file.path, from: root))
      .toList()
    ..sort();
}

typedef _RuntimeSource = ({bool dartMarker, bool flutter, Set<String> local});

class _RuntimeSources {
  _RuntimeSources(this.root) {
    package =
        RegExp(
          r'^name:\s*([a-z][a-z0-9_]*)\s*$',
          multiLine: true,
        ).firstMatch(File('$root/pubspec.yaml').readAsStringSync())?.group(1) ??
        '';
  }

  final String root;
  late final String package;
  final _cache = <String, _RuntimeSource>{};
  var _size = 0;

  Future<_RuntimeSource> read(String file) async {
    if ((!isGraphSource(file) && file != 'flutter_test_config.dart') ||
        path.posix.normalize(file) != file) {
      throw const FormatException(
        'A test dependency escapes the source graph.',
      );
    }
    if (_cache[file] case final cached?) return cached;
    if (_cache.length >= 3000) {
      throw const FormatException('Test graph is too large.');
    }
    final source = File('$root/$file');
    if (FileSystemEntity.isLinkSync(source.path)) {
      throw const FormatException('A test dependency is a symbolic link.');
    }
    if (!path.isWithin(
      Directory(root).resolveSymbolicLinksSync(),
      source.resolveSymbolicLinksSync(),
    )) {
      throw const FormatException('A test dependency escapes the project.');
    }
    final size = await source.length();
    _size += size;
    if (size > 2 * 1024 * 1024 || _size > 32 * 1024 * 1024) {
      throw const FormatException('Test graph exceeds its size limit.');
    }
    final parsed = parseString(
      content: await source.readAsString(),
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    var marker = false;
    var flutter = parsed.errors.isNotEmpty || package.isEmpty;
    final local = <String>{};
    for (final directive in parsed.unit.directives) {
      for (final uri in directiveUris(directive)) {
        marker |=
            directive is ImportDirective && uri == 'package:test/test.dart';
        flutter |=
            uri == 'dart:ui' ||
            uri.startsWith('package:flutter') ||
            RegExp(r'^package:[^/]+_flutter/').hasMatch(uri);
        final dependency = _localDependency(file, uri);
        if (dependency != null) local.add(dependency);
      }
    }
    return _cache[file] = (dartMarker: marker, flutter: flutter, local: local);
  }

  String? _localDependency(String file, String uri) {
    final prefix = 'package:$package/';
    if (uri.startsWith(prefix)) {
      final target = 'lib/${Uri.decodeComponent(uri.substring(prefix.length))}';
      if (path.posix.normalize(target) != target) {
        throw const FormatException('A package URI escapes the source graph.');
      }
    }
    return resolveDependency(file, uri, package);
  }

  Future<({bool flutter, Set<String> production})> context(String test) async {
    final config = _flutterConfiguration(test);
    final pending = [test, ?config];
    final visited = <String>{};
    var flutter = config != null;
    final production = <String>{};
    while (pending.isNotEmpty) {
      final file = pending.removeLast();
      if (!visited.add(file)) continue;
      final source = await read(file);
      flutter |= source.flutter;
      if (file.startsWith('lib/')) production.add(file);
      pending.addAll(source.local);
    }
    return (flutter: flutter, production: production);
  }

  String? _flutterConfiguration(String test) {
    var directory = path.posix.dirname(test);
    while (true) {
      final config = path.posix.normalize(
        path.posix.join(directory, 'flutter_test_config.dart'),
      );
      if (FileSystemEntity.typeSync('$root/$config', followLinks: false) !=
          FileSystemEntityType.notFound) {
        return config;
      }
      if (directory == '.' ||
          File('$root/$directory/pubspec.yaml').existsSync()) {
        return null;
      }
      directory = path.posix.dirname(directory);
    }
  }
}
