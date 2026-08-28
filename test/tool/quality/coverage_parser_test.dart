import 'package:flutter_test/flutter_test.dart';

import '../../../tool/quality/check_coverage.dart';
import 'coverage_test_support.dart';

void main() {
  _registerNativeParsingTest();
  _registerMixedFormatTest();
  _registerMaintainedSourceTest();
  _registerMalformedLcovTests();
}

void _registerNativeParsingTest() {
  test('parses native line, function, and branch records', () {
    final fixture = CoverageFixture.create({
      'native.dart': 'int choose(bool value) => value ? 1 : 0;\n',
    });
    addTearDown(fixture.dispose);

    final report = CoverageReport.parse(
      fixture.record('native.dart', [
        'FNDA:2,choose',
        'DA:1,2',
        'BRDA:1,0,0,2',
        'BRDA:1,0,1,-',
      ]),
      sources: fixture.sources,
    );

    expect(report.coveredLines, 1);
    expect(report.totalLines, 1);
    expect(report.coveredFunctions, 1);
    expect(report.totalFunctions, 1);
    expect(report.coveredBranches, 1);
    expect(report.totalBranches, 2);
  });
}

void _registerMixedFormatTest() {
  test('selects native or derived formats independently per source', () {
    const source = '''
int choose(bool value) {
  if (value) {
    return 1;
  } else {
    return 0;
  }
}
''';
    final fixture = CoverageFixture.create({
      'native.dart': source,
      'derived.dart': source,
    });
    addTearDown(fixture.dispose);
    final entryLine = fixture.lineOf('native.dart', 'int choose');
    final thenLine = fixture.lineOf('native.dart', 'return 1');
    final elseLine = fixture.lineOf('native.dart', 'return 0');
    final lcov = [
      ...fixture.record('native.dart', [
        'FNDA:0,choose',
        'DA:$entryLine,1',
        'DA:$thenLine,1',
        'DA:$elseLine,0',
        'BRDA:$entryLine,0,0,-',
      ]),
      ...fixture.record('derived.dart', [
        'DA:$entryLine,1',
        'DA:$thenLine,1',
        'DA:$elseLine,0',
      ]),
    ];

    final report = CoverageReport.parse(lcov, sources: fixture.sources);

    expect(report.coveredFunctions, 1);
    expect(report.totalFunctions, 2);
    expect(report.coveredBranches, 1);
    expect(report.totalBranches, 3);
  });
}

void _registerMaintainedSourceTest() {
  test('ignores reported sources outside the maintained source set', () {
    final fixture = CoverageFixture.create({
      'maintained.dart': 'int maintained() => 1;\n',
      'extra.dart': 'int extra() => 2;\n',
    });
    addTearDown(fixture.dispose);
    final maintainedOnly = {
      fixture.path('maintained.dart'): 'lib/maintained.dart',
    };
    final lcov = [
      ...fixture.record('maintained.dart', [
        'DA:1,0',
        'FNDA:0,maintained',
        'BRDA:1,0,0,-',
      ]),
      ...fixture.record('extra.dart', [
        'DA:1,10',
        'FNDA:10,extra',
        'BRDA:1,0,0,10',
      ]),
    ];

    final report = CoverageReport.parse(lcov, sources: maintainedOnly);

    expect(report.coveredLines, 0);
    expect(report.totalLines, 1);
    expect(report.coveredFunctions, 0);
    expect(report.totalFunctions, 1);
    expect(report.coveredBranches, 0);
    expect(report.totalBranches, 1);
  });
}

void _registerMalformedLcovTests() {
  group('malformed LCOV', () {
    final cases = <String, List<String>>{
      'DA outside source': ['DA:1,1'],
      'empty source': ['SF:', 'end_of_record'],
      'nested source': ['SF:a.dart', 'SF:b.dart'],
      'duplicate source': [
        'SF:a.dart',
        'end_of_record',
        'SF:a.dart',
        'end_of_record',
      ],
      'orphan terminator': ['end_of_record'],
      'unterminated source': ['SF:a.dart'],
      'malformed DA': ['SF:a.dart', 'DA:1', 'end_of_record'],
      'invalid DA line': ['SF:a.dart', 'DA:0,1', 'end_of_record'],
      'negative DA hits': ['SF:a.dart', 'DA:1,-1', 'end_of_record'],
      'duplicate DA': ['SF:a.dart', 'DA:1,1', 'DA:1,0', 'end_of_record'],
      'malformed BRDA': ['SF:a.dart', 'BRDA:1,0,0', 'end_of_record'],
      'invalid BRDA block': ['SF:a.dart', 'BRDA:1,x,0,1', 'end_of_record'],
      'invalid BRDA branch': ['SF:a.dart', 'BRDA:1,0,x,1', 'end_of_record'],
      'negative BRDA hits': ['SF:a.dart', 'BRDA:1,0,0,-1', 'end_of_record'],
      'duplicate BRDA': [
        'SF:a.dart',
        'BRDA:1,0,0,1',
        'BRDA:1,0,0,0',
        'end_of_record',
      ],
      'malformed FNDA': ['SF:a.dart', 'FNDA:', 'end_of_record'],
      'negative FNDA hits': ['SF:a.dart', 'FNDA:-1,name', 'end_of_record'],
      'duplicate FNDA': [
        'SF:a.dart',
        'FNDA:1,name',
        'FNDA:0,name',
        'end_of_record',
      ],
    };

    for (final entry in cases.entries) {
      test('rejects ${entry.key}', () {
        expect(
          () => CoverageReport.parse(entry.value, sources: const {}),
          throwsA(isA<FormatException>()),
        );
      });
    }
  });
}
