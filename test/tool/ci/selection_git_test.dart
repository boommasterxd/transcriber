import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../../../tool/ci/selection_git.dart';
import '../../../tool/ci/selection_git_objects.dart';
import 'git_fixture.dart';

void main() {
  late GitFixture fixture;
  setUp(() async => fixture = await GitFixture.create());
  tearDown(() => fixture.dispose());

  test(
    'bulk reads ordered Unicode sources and unusual tracked paths',
    () async {
      const name = 'lib/space and\nnewline_ä.dart';
      const source = "const title = 'Größe';\n";
      await fixture.write({name: source});
      final revision = await fixture.commit();
      final files = await SelectionGit(
        fixture.directory.path,
      ).readFiles(revision, ['lib/second.dart', name, 'lib/first.dart']);
      expect(files.keys, ['lib/second.dart', name, 'lib/first.dart']);
      expect(files[name], source);
      expect(files['lib/first.dart'], fixtureSource('first', 1));
    },
  );

  test(
    'bulk read rejects missing objects instead of returning partial data',
    () async {
      await expectLater(
        SelectionGit(
          fixture.directory.path,
        ).readFiles(fixture.base, ['lib/first.dart', 'lib/missing.dart']),
        throwsFormatException,
      );
    },
  );

  test('bulk read accepts an empty source request', () async {
    expect(
      await SelectionGit(fixture.directory.path).readFiles(fixture.base, []),
      isEmpty,
    );
  });

  test('bulk read rejects requests containing a null path separator', () async {
    await expectLater(
      SelectionGit(
        fixture.directory.path,
      ).readFiles(fixture.base, ['bad\u0000path']),
      throwsFormatException,
    );
  });

  test('bulk output is bounded before decoding oversized objects', () async {
    await fixture.write({'large.txt': 'a' * (33 * 1024 * 1024)});
    final revision = await fixture.commit();
    await expectLater(
      SelectionGit(fixture.directory.path).readFiles(revision, ['large.txt']),
      throwsFormatException,
    );
  });

  registerFramingTests();
}

void registerFramingTests() {
  final header = '${'a' * 40} blob ';
  final cases = <String, List<int>>{
    'missing header': [],
    'missing object': utf8.encode('missing missing\n'),
    'non-blob object': utf8.encode('${'a' * 40} tree 0\n\n'),
    'oversized source': utf8.encode('${header}2097153\n'),
    'truncated content': utf8.encode('${header}4\nabc'),
    'missing record delimiter': utf8.encode('${header}1\na!'),
    'extra output': utf8.encode('${header}1\na\nextra'),
    'invalid UTF8': [...utf8.encode('${header}1\n'), 255, 10],
  };
  for (final entry in cases.entries) {
    test('bulk parser rejects ${entry.key}', () {
      expect(
        () => parseGitFiles(Uint8List.fromList(entry.value), ['source.dart']),
        throwsFormatException,
      );
    });
  }
  test('bulk parser rejects duplicate requested paths', () {
    final record = utf8.encode('${header}1\na\n');
    expect(
      () =>
          parseGitFiles(Uint8List.fromList([...record, ...record]), ['a', 'a']),
      throwsFormatException,
    );
  });
}
