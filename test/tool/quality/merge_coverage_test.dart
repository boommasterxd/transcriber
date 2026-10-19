import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/quality/check_coverage.dart';
import 'coverage_test_support.dart';
import 'mixed_coverage_fixture.dart';

const _choice = '''
int choice(bool flag) {
  if (flag) {
    return 1;
  } else {
    return 2;
  }
}
''';

void main() {
  late CoverageFixture fixture;
  setUp(() => fixture = CoverageFixture.create({'choice.dart': _choice}));
  tearDown(() => fixture.dispose());
  _registerUnionTests(() => fixture);
  _registerInvalidReportTests(() => fixture);
  _registerFileTests(() => fixture);
  _registerBoundaryTests(() => fixture);
  _registerCoverageExpectationTests(() => fixture);
  _registerRuntimeIntegrationTest();
}

void _registerBoundaryTests(CoverageFixture Function() getFixture) {
  test('rejects canonical duplicate sources and paths outside the project', () {
    final fixture = getFixture();
    final record = _record(fixture, first: 1, second: 1);
    expect(
      () => mergeLcovReports([
        [...record, ...record],
      ], root: fixture.directory.path),
      throwsFormatException,
    );
    final outside = Directory.systemTemp.createTempSync('outside-coverage-');
    addTearDown(() => outside.deleteSync(recursive: true));
    final source = File('${outside.path}/outside.dart')
      ..writeAsStringSync('int value() => 1;\n');
    expect(
      () => mergeLcovReports([
        ['SF:${source.path}', 'DA:1,1', 'end_of_record'],
      ], root: fixture.directory.path),
      throwsFormatException,
    );
  });
  test('rejects aliases of the same runtime report', () async {
    final fixture = getFixture();
    final file = File('${fixture.directory.path}/runtime.info')
      ..writeAsStringSync(_record(fixture, first: 1, second: 1).join('\n'));
    await expectLater(
      mergeCoverageFiles([
        file.path,
        '${fixture.directory.path}/./runtime.info',
      ], '${fixture.directory.path}/result.info'),
      throwsFormatException,
    );
  });
  test('rejects oversized and invalid UTF8 runtime report files', () async {
    final fixture = getFixture();
    final input = File('${fixture.directory.path}/oversized.info');
    final handle = input.openSync(mode: FileMode.write);
    handle.truncateSync(33 * 1024 * 1024);
    handle.closeSync();
    final output = '${fixture.directory.path}/result.info';
    await expectLater(
      mergeCoverageFiles([input.path], output),
      throwsFormatException,
    );
    input.writeAsBytesSync([255]);
    await expectLater(
      mergeCoverageFiles([input.path], output),
      throwsFormatException,
    );
    expect(File(output).existsSync(), isFalse);
  });
}

void _registerCoverageExpectationTests(CoverageFixture Function() getFixture) {
  test('requires application coverage for reachable executable sources', () {
    final fixture = getFixture();
    expect(hasExecutableAppSources([], root: fixture.directory.path), isFalse);
    expect(
      hasExecutableAppSources([
        'lib/choice.dart',
      ], root: fixture.directory.path),
      isTrue,
    );
    File(
      '${fixture.directory.path}/lib/fragment.dart',
    ).writeAsStringSync('part of sample;\n');
    File(
      '${fixture.directory.path}/lib/contracts.dart',
    ).writeAsStringSync('abstract interface class Port { void run(); }\n');
    expect(
      hasExecutableAppSources([
        'lib/fragment.dart',
        'lib/contracts.dart',
      ], root: fixture.directory.path),
      isFalse,
    );
  });
  test('fails closed for invalid reachable application source paths', () {
    final fixture = getFixture();
    expect(
      () => hasExecutableAppSources([
        'test/example.dart',
      ], root: fixture.directory.path),
      throwsFormatException,
    );
    expect(
      () => hasExecutableAppSources([
        'lib/absent.dart',
      ], root: fixture.directory.path),
      throwsA(isA<FileSystemException>()),
    );
  });
}

void _registerRuntimeIntegrationTest() {
  test(
    'real Dart and Flutter coverage combine complementary branches',
    () async {
      final fixture = await MixedCoverageFixture.create(_choice);
      addTearDown(fixture.dispose);
      final reports = [
        await fixture.collect('dart'),
        await fixture.collect('flutter'),
      ];
      final source = File(
        '${fixture.root.path}/lib/choice.dart',
      ).resolveSymbolicLinksSync();
      final sources = {source: 'lib/choice.dart'};
      for (final report in reports) {
        final single = CoverageReport.parse(
          report
              .map((line) => line.startsWith('SF:') ? 'SF:$source' : line)
              .toList(),
          sources: sources,
        );
        expect(single.branchRate, lessThan(80));
        expect(single.thresholdFailures(), isNotEmpty);
        expect(report.any((line) => line.startsWith('FNDA:')), isFalse);
      }
      final merged = CoverageReport.parse(
        mergeLcovReports(reports, root: fixture.root.path).split('\n'),
        sources: sources,
      );
      expect(merged.branchRate, 100);
      expect(merged.thresholdFailures(), isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

void _registerUnionTests(CoverageFixture Function() getFixture) {
  test('unions complementary runtime branches without counting code twice', () {
    final fixture = getFixture();
    final first = _record(fixture, first: 1, second: 0);
    final second = _record(fixture, first: 0, second: 1);
    for (final report in [first, second]) {
      final single = CoverageReport.parse(report, sources: fixture.sources);
      expect(single.thresholdFailures(), isNotEmpty);
      expect(single.branchRate, 50);
    }
    final merged = CoverageReport.parse(
      mergeLcovReports([
        first,
        second,
      ], root: fixture.directory.path).split('\n'),
      sources: fixture.sources,
    );
    expect(merged.totalSources, 1);
    expect(merged.totalLines, 4);
    expect(merged.totalFunctions, 1);
    expect(merged.totalBranches, 2);
    expect(merged.thresholdFailures(), isEmpty);
  });

  test('keeps unhit lines and combines overlapping hits by maximum', () {
    final fixture = getFixture();
    final first = _record(fixture, first: 3, second: 0);
    final second = _record(fixture, first: 2, second: 0);
    final merged = mergeLcovReports([
      first,
      second,
    ], root: fixture.directory.path);
    expect(merged, contains('DA:3,3\n'));
    expect(merged, contains('DA:5,0\n'));
    expect(merged, contains('BRDA:3,0,0,3\n'));
    expect(merged, contains('BRDA:5,0,0,0\n'));
    expect(merged, isNot(contains('FNDA:')));
  });

  test('canonicalizes relative source paths to the same existing file', () {
    final fixture = getFixture();
    final absolute = _record(fixture, first: 1, second: 0);
    final relative = _record(fixture, first: 0, second: 1)
      ..[0] = 'SF:lib/../lib/choice.dart';
    final merged = mergeLcovReports([
      absolute,
      relative,
    ], root: fixture.directory.path);
    expect('SF:'.allMatches(merged), hasLength(1));
    expect(merged, startsWith('SF:${fixture.path('choice.dart')}\n'));
  });

  test('does not invent coverage for an unexecuted production source', () {
    final fixture = getFixture();
    final missing = File('${fixture.directory.path}/lib/missing.dart')
      ..writeAsStringSync('int missing() => 1;\n');
    final sources = {...fixture.sources, missing.path: 'lib/missing.dart'};
    final merged = mergeLcovReports([
      _record(fixture, first: 1, second: 1),
    ], root: fixture.directory.path);
    final report = CoverageReport.parse(merged.split('\n'), sources: sources);
    expect(report.missingSources, ['lib/missing.dart']);
    expect(report.thresholdFailures().first, contains('Coverage is missing 1'));
  });
}

void _registerInvalidReportTests(CoverageFixture Function() getFixture) {
  final invalid = <String, List<String>>{
    'empty runtime': [],
    'truncated source': ['SF:lib/choice.dart', 'DA:1,1'],
    'unknown record': ['SF:lib/choice.dart', 'NOT_A_RECORD', 'end_of_record'],
    'native functions': [
      'SF:lib/choice.dart',
      'FNDA:1,choice',
      'end_of_record',
    ],
    'invalid line count': ['SF:lib/choice.dart', 'DA:1,-1', 'end_of_record'],
    'duplicate line': [
      'SF:lib/choice.dart',
      'DA:1,1',
      'DA:1,0',
      'end_of_record',
    ],
    'invalid summary': [
      'SF:lib/choice.dart',
      'DA:1,1',
      'LF:2',
      'end_of_record',
    ],
    'duplicate summary': [
      'SF:lib/choice.dart',
      'DA:1,1',
      'LF:1',
      'LF:1',
      'end_of_record',
    ],
    'orphan summary': ['LF:1'],
    'empty record': ['SF:lib/choice.dart', 'end_of_record'],
    'source without end': ['SF:lib/choice.dart', 'DA:1,1'],
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.key}', () {
      final fixture = getFixture();
      expect(
        () => mergeLcovReports([entry.value], root: fixture.directory.path),
        throwsFormatException,
      );
    });
  }
  test('rejects no expected runtimes or more than two runtime inputs', () {
    final fixture = getFixture();
    expect(
      () => mergeLcovReports([], root: fixture.directory.path),
      throwsFormatException,
    );
    expect(
      () => mergeLcovReports([[], [], []], root: fixture.directory.path),
      throwsFormatException,
    );
  });
  test('rejects absent and non-Dart source paths', () {
    final fixture = getFixture();
    expect(
      () => mergeLcovReports([
        ['SF:lib/absent.dart', 'end_of_record'],
      ], root: fixture.directory.path),
      throwsA(isA<FileSystemException>()),
    );
    final other = File('${fixture.directory.path}/other.txt')
      ..writeAsStringSync('text');
    expect(
      () => mergeLcovReports([
        ['SF:${other.path}', 'end_of_record'],
      ], root: fixture.directory.path),
      throwsFormatException,
    );
  });
  test('rejects mismatched or unavailable shared branch layouts', () {
    final fixture = getFixture();
    final first = _record(fixture, first: 1, second: 0);
    for (final other in [
      _record(fixture, first: 0, second: 1)
        ..removeWhere((line) => line.startsWith('BRDA:')),
      _record(fixture, first: 0, second: 1)..[6] = 'BRDA:5,0,1,1',
    ]) {
      expect(
        () => mergeLcovReports([first, other], root: fixture.directory.path),
        throwsFormatException,
      );
    }
  });
}

void _registerFileTests(CoverageFixture Function() getFixture) {
  test(
    'writes the merged report only after all expected inputs validate',
    () async {
      final fixture = getFixture();
      final first = File('${fixture.directory.path}/first.info')
        ..writeAsStringSync(_record(fixture, first: 1, second: 0).join('\n'));
      final second = File('${fixture.directory.path}/second.info')
        ..writeAsStringSync(_record(fixture, first: 0, second: 1).join('\n'));
      final output = '${fixture.directory.path}/merged/lcov.info';
      await mergeCoverageFiles(
        [first.path, second.path],
        output,
        root: fixture.directory.path,
      );
      expect(File(output).readAsStringSync(), contains('BRDA:5,0,0,1'));
      second.writeAsStringSync('');
      File(output).deleteSync();
      await expectLater(
        mergeCoverageFiles(
          [first.path, second.path],
          output,
          root: fixture.directory.path,
        ),
        throwsFormatException,
      );
      expect(File(output).existsSync(), isFalse);
    },
  );
  test('rejects absent and duplicate runtime files', () async {
    final fixture = getFixture();
    final output = '${fixture.directory.path}/merged.info';
    await expectLater(
      mergeCoverageFiles(['absent.info'], output, root: fixture.directory.path),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      mergeCoverageFiles(['same', 'same'], output),
      throwsFormatException,
    );
    await expectLater(mergeCoverageFiles([], output), throwsFormatException);
  });
}

List<String> _record(
  CoverageFixture fixture, {
  required int first,
  required int second,
}) => fixture.record('choice.dart', [
  'DA:1,1',
  'DA:2,1',
  'DA:3,$first',
  'DA:5,$second',
  'BRDA:3,0,0,$first',
  'BRDA:5,0,0,$second',
  'LF:4',
  'LH:${2 + (first > 0 ? 1 : 0) + (second > 0 ? 1 : 0)}',
]);
