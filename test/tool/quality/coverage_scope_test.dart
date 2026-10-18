import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/quality/check_coverage.dart';
import '../ci/git_fixture.dart';
import 'coverage_test_support.dart';

void main() {
  _registerOptionsTests();
  _registerScopeTests();
  _registerPartialReportTests();
}

void _registerOptionsTests() {
  test(
    'defaults to complete coverage and preserves the explicit LCOV path',
    () {
      final defaults = CoverageOptions.parse([]);
      expect(defaults.lcovPath, 'coverage/lcov.info');
      expect(defaults.scopePlan, isNull);
      final explicit = CoverageOptions.parse(['custom.info']);
      expect(explicit.lcovPath, 'custom.info');
      expect(explicit.scopePlan, isNull);
    },
  );
  test('requires an explicit plan option for scoped coverage', () {
    for (final arguments in [
      ['custom.info', '--scope-plan', 'plan.json'],
      ['--scope-plan', 'plan.json', 'custom.info'],
    ]) {
      final options = CoverageOptions.parse(arguments);
      expect(options.lcovPath, 'custom.info');
      expect(options.scopePlan, 'plan.json');
    }
    expect(
      CoverageOptions.parse(['--scope-plan', 'plan.json']).lcovPath,
      'coverage/lcov.info',
    );
  });
  final invalidArguments = [
    ['--scope-plan'],
    ['--scope-plan', ''],
    ['--scope-plan', '--unknown'],
    ['--scope-plan', 'first', '--scope-plan', 'second'],
    ['--unknown'],
    ['first.info', 'second.info'],
    [''],
  ];
  for (final arguments in invalidArguments) {
    test('rejects ambiguous coverage arguments $arguments', () {
      expect(() => CoverageOptions.parse(arguments), throwsFormatException);
    });
  }
}

void _registerScopeTests() {
  group('validated coverage scopes', () {
    late GitFixture fixture;
    setUp(() async => fixture = await GitFixture.create());
    tearDown(() async => fixture.dispose());

    test('keeps the complete source inventory without a plan', () async {
      final scope = await CoverageScope.load(null, root: fixture.directory);
      expect(scope.isPartial, isFalse);
      expect(
        scope.sources.values,
        containsAll(['lib/first.dart', 'lib/second.dart']),
      );
      expect(scope.sources, hasLength(2));
    });

    test(
      'restricts source inventory to the validated affected sources',
      () async {
        await fixture.write({
          'lib/second.dart': "export 'first.dart';\n",
          'lib/unrelated.dart': 'const unrelated = 3;\n',
          'test/unrelated_test.dart': "import '../lib/unrelated.dart';\n",
        });
        fixture.base = await fixture.commit();
        final plan = await fixture.plan({
          'lib/first.dart': fixtureSource('first', 3),
        });
        expect(plan['mode'], 'selected');
        final scope = await _loadPlan(fixture, plan);
        expect(scope.isPartial, isTrue);
        expect(scope.sources.values, ['lib/first.dart']);
      },
    );

    test('preserves full coverage for a fallback plan', () async {
      final plan = await fixture.plan({'README.md': 'Updated instructions.\n'});
      final scope = await _loadPlan(fixture, plan);
      expect(scope.isPartial, isFalse);
      expect(scope.sources, hasLength(2));
    });

    test(
      'permits no application scope only for verified independent tests',
      () async {
        final plan = await fixture.plan({
          'test/tool/independent_test.dart': 'void main() {}\n',
        });
        final scope = await _loadPlan(fixture, plan);
        expect(scope.isPartial, isTrue);
        expect(scope.sources, isEmpty);
      },
    );

    for (final field in ['tests', 'affectedSources']) {
      test('rejects a manipulated empty $field list', () async {
        final plan = await fixture.plan({
          'lib/first.dart': fixtureSource('first', 3),
        });
        expect(plan['mode'], 'selected');
        plan[field] = <String>[];
        await expectLater(_loadPlan(fixture, plan), throwsFormatException);
      });
    }
    test('rejects malformed JSON before interpreting its scope', () async {
      await fixture.write({'invalid.json': '{'});
      await expectLater(
        CoverageScope.load(
          '${fixture.directory.path}/invalid.json',
          root: fixture.directory,
        ),
        throwsFormatException,
      );
    });
  });
}

Future<CoverageScope> _loadPlan(
  GitFixture fixture,
  Map<String, Object?> plan,
) async {
  await fixture.write({'coverage-plan.json': jsonEncode(plan)});
  return CoverageScope.load(
    '${fixture.directory.path}/coverage-plan.json',
    root: fixture.directory,
  );
}

void _registerPartialReportTests() {
  test('explicitly reports no application coverage for independent tests', () {
    final report = CoverageReport.parse([], sources: {}, isPartial: true);
    expect(report.thresholdFailures(), isEmpty);
    expect(report.summary(), startsWith('Partial coverage:'));
    expect(report.summary(), contains('No application coverage was measured'));
    expect(report.summary(), contains('full coverage was not checked'));
    expect(
      CoverageReport.parse([], sources: {}).thresholdFailures(),
      hasLength(4),
    );
  });

  test('scoped coverage keeps missing-source and empty-metric failures', () {
    final fixture = CoverageFixture.create({
      'missing.dart': 'int value() => 1;\n',
    });
    addTearDown(fixture.dispose);
    final report = CoverageReport.parse(
      [],
      sources: fixture.sources,
      isPartial: true,
    );
    expect(report.summary(), startsWith('Partial coverage (selected scope):'));
    expect(report.missingSources, ['lib/missing.dart']);
    expect(report.thresholdFailures(), hasLength(5));
  });

  test('scoped coverage enforces every unchanged threshold', () {
    final fixture = CoverageFixture.create({'low.dart': 'int value() => 1;\n'});
    addTearDown(fixture.dispose);
    final report = CoverageReport.parse(
      fixture.record('low.dart', ['DA:1,0', 'FNDA:0,value', 'BRDA:1,0,0,0']),
      sources: fixture.sources,
      isPartial: true,
    );
    expect(report.thresholdFailures(), hasLength(4));
    expect(report.thresholdFailures().last, contains('required 80.0%'));
    expect(report.thresholdFailures().first, contains('required 85.0%'));
  });
}
