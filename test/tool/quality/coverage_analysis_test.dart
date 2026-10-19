import 'package:test/test.dart';

import '../../../tool/quality/check_coverage.dart';
import 'coverage_test_support.dart';

const _branchSource = '''
int branches(int value, bool flag) {
  var total = 0;
  if (flag) {
    total += 1;
  } else {
    total += 2;
  }
  switch (value) {
    case 0:
      total += 3;
    default:
      total += 4;
  }
  for (var index = 0; index < value; index++) {
    total += 5;
  }
  while (flag) {
    total += 6;
    break;
  }
  do {
    total += 7;
  } while (false);
  try {
    total += 8;
  } catch (_) {
    total += 9;
  }
  total += flag
      ? 10
      : 11;
  if (flag == true
      && value > 0) {
    total += 12;
  }
  return switch (value) {
    0 => total + 1,
    _ => total,
  };
}
''';

void main() {
  _registerNonInstrumentableSourceTest();
  _registerInvalidSourceTest();
  _registerDerivedBranchTest();
  _registerMissingBranchTest();
  _registerBoundaryThresholdTest();
  _registerBelowThresholdTest();
  _registerMissingSourceTest();
}

void _registerNonInstrumentableSourceTest() {
  test('reports analyzer-classified non-instrumentable sources', () {
    final fixture = CoverageFixture.create({
      'fragment.dart': "part of 'sample.dart';\nconst values = {'a': 1};\n",
      'contracts.dart': '''
abstract interface class Port {
  void run();
}
typedef Callback = void Function();
''',
      'executable.dart': 'int execute() => 1;\n',
    });
    addTearDown(fixture.dispose);

    final report = CoverageReport.parse(
      fixture.record('executable.dart', [
        'DA:1,1',
        'FNDA:1,execute',
        'BRDA:1,0,0,1',
      ]),
      sources: fixture.sources,
    );

    expect(report.maintainedSources, 3);
    expect(report.totalSources, 1);
    expect(report.coveredSources, 1);
    expect(report.missingSources, isEmpty);
    expect(report.nonInstrumentableSources, {
      'lib/contracts.dart': 'abstract interfaces and typedefs only',
      'lib/fragment.dart': 'constant data and memberless enums only',
    });
    expect(report.summary(), contains('lib/contracts.dart'));
    expect(report.summary(), contains('lib/fragment.dart'));
  });
}

void _registerInvalidSourceTest() {
  test('rejects maintained source that the analyzer cannot parse', () {
    final fixture = CoverageFixture.create({'invalid.dart': 'int broken( {\n'});
    addTearDown(fixture.dispose);

    expect(
      () => CoverageReport.parse(const [], sources: fixture.sources),
      throwsA(isA<FormatException>()),
    );
  });
}

void _registerDerivedBranchTest() {
  test('derives documented branch paths only where DA records exist', () {
    final fixture = CoverageFixture.create({'branches.dart': _branchSource});
    addTearDown(fixture.dispose);
    final hitLines = <String, int>{
      'total += 1': 1,
      'total += 2': 0,
      'total += 3': 1,
      'total += 4': 0,
      'total += 5': 1,
      'total += 6': 0,
      'total += 7': 1,
      'total += 9': 0,
      '? 10': 1,
      ': 11': 0,
      'if (flag == true': 1,
      '&& value': 0,
      'total += 12': 1,
      '0 => total': 1,
      '_ => total': 0,
    };
    final records = hitLines.entries.map(
      (entry) =>
          'DA:${fixture.lineOf('branches.dart', entry.key)},${entry.value}',
    );

    final report = CoverageReport.parse(
      fixture.record('branches.dart', records),
      sources: fixture.sources,
    );

    expect(report.totalBranches, 15);
    expect(report.coveredBranches, 8);
  });
}

void _registerMissingBranchTest() {
  test('does not invent branch coverage without native or derived paths', () {
    final fixture = CoverageFixture.create({
      'straight.dart': 'int straight() => 1;\n',
    });
    addTearDown(fixture.dispose);

    final report = CoverageReport.parse(
      fixture.record('straight.dart', ['DA:1,1', 'FNDA:1,straight']),
      sources: fixture.sources,
    );

    expect(report.totalBranches, 0);
    expect(
      report.thresholdFailures(),
      contains('Branch coverage has no instrumented records.'),
    );
  });
}

void _registerBoundaryThresholdTest() {
  test('accepts the unchanged thresholds at their exact boundaries', () {
    final fixture = CoverageFixture.create({
      'limits.dart': 'int limit() => 1;\n',
    });
    addTearDown(fixture.dispose);
    final records = <String>[
      for (var line = 1; line <= 20; line++) 'DA:$line,${line <= 17 ? 1 : 0}',
      for (var function = 1; function <= 20; function++)
        'FNDA:${function <= 17 ? 1 : 0},function$function',
      for (var branch = 1; branch <= 10; branch++)
        'BRDA:1,0,$branch,${branch <= 8 ? 1 : 0}',
    ];

    final report = CoverageReport.parse(
      fixture.record('limits.dart', records),
      sources: fixture.sources,
    );

    expect(report.lineRate, 85);
    expect(report.statementRate, 85);
    expect(report.functionRate, 85);
    expect(report.branchRate, 80);
    expect(report.thresholdFailures(), isEmpty);
  });
}

void _registerBelowThresholdTest() {
  test('fails all unchanged thresholds when rates are below them', () {
    final fixture = CoverageFixture.create({'low.dart': 'int low() => 1;\n'});
    addTearDown(fixture.dispose);
    final records = <String>[
      for (var line = 1; line <= 20; line++) 'DA:$line,${line <= 16 ? 1 : 0}',
      for (var function = 1; function <= 4; function++)
        'FNDA:${function <= 3 ? 1 : 0},function$function',
      for (var branch = 1; branch <= 5; branch++)
        'BRDA:1,0,$branch,${branch <= 3 ? 1 : 0}',
    ];

    final failures = CoverageReport.parse(
      fixture.record('low.dart', records),
      sources: fixture.sources,
    ).thresholdFailures();

    expect(failures, hasLength(4));
    expect(failures, contains(startsWith('Line coverage is 80.00%')));
    expect(
      failures,
      contains(startsWith('Statement proxy coverage is 80.00%')),
    );
    expect(failures, contains(startsWith('Function proxy coverage is 75.00%')));
    expect(failures, contains(startsWith('Branch coverage is 60.00%')));
  });
}

void _registerMissingSourceTest() {
  test(
    'reports executable maintained sources with no DA records as missing',
    () {
      final fixture = CoverageFixture.create({
        'missing.dart': 'int missing() => 1;\n',
      });
      addTearDown(fixture.dispose);

      final report = CoverageReport.parse(const [], sources: fixture.sources);

      expect(report.missingSources, ['lib/missing.dart']);
      expect(report.coveredSources, 0);
      expect(report.totalSources, 1);
      expect(
        report.thresholdFailures().first,
        contains('Coverage is missing 1 executable maintained source files'),
      );
    },
  );
}
