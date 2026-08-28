import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/quality/check_coverage.dart';

void main() {
  group('discoverMaintainedSources', () {
    test('includes existing tracked and untracked lib Dart sources', () {
      final root = Directory.systemTemp.createTempSync('coverage-discovery-');
      addTearDown(() => root.deleteSync(recursive: true));
      _git(root, ['init', '--quiet']);
      _write(root, '.gitignore', 'lib/ignored.dart\n');
      _write(root, 'lib/tracked.dart', 'int tracked() => 1;\n');
      _write(root, 'lib/untracked.dart', 'int untracked() => 2;\n');
      _write(root, 'lib/ignored.dart', 'int ignored() => 3;\n');
      _write(root, 'lib/deleted.dart', 'int deleted() => 4;\n');
      _write(root, 'lib/not_dart.txt', 'not Dart\n');
      _git(root, ['add', 'lib/tracked.dart', 'lib/deleted.dart']);
      File('${root.path}/lib/deleted.dart').deleteSync();

      final result = discoverMaintainedSources(root: root);

      expect(
        result.values,
        containsAll(['lib/tracked.dart', 'lib/untracked.dart']),
      );
      expect(result.values, isNot(contains('lib/ignored.dart')));
      expect(result.values, isNot(contains('lib/deleted.dart')));
      expect(result.values, isNot(contains('lib/not_dart.txt')));
      expect(result, hasLength(2));
    });

    test('fails closed when git cannot enumerate a repository', () {
      final root = Directory.systemTemp.createTempSync('coverage-no-git-');
      addTearDown(() => root.deleteSync(recursive: true));

      expect(
        () => discoverMaintainedSources(root: root),
        throwsA(isA<StateError>()),
      );
    });

    test('fails closed when the repository has no maintained Dart source', () {
      final root = Directory.systemTemp.createTempSync('coverage-empty-git-');
      addTearDown(() => root.deleteSync(recursive: true));
      _git(root, ['init', '--quiet']);

      expect(
        () => discoverMaintainedSources(root: root),
        throwsA(isA<StateError>()),
      );
    });
  });
}

void _write(Directory root, String path, String contents) {
  final file = File('${root.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

void _git(Directory root, List<String> arguments) {
  final result = Process.runSync('git', arguments, workingDirectory: root.path);
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
}
