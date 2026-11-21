import 'dart:convert';

import 'package:test/test.dart';

import '../../../tool/quality/check_coverage.dart';
import '../ci/git_fixture.dart';

void main() {
  late GitFixture fixture;
  setUp(() async {
    fixture = await GitFixture.create();
    await fixture.write({
      'lib/first.dart': "part 'fragment.dart';\n${fixtureSource('first', 1)}",
      'lib/fragment.dart':
          "part of 'first.dart';\n${fixtureSource('fragment', 1)}",
      'lib/data.dart': "part of 'first.dart';\nconst values = {'value': 1};",
    });
    fixture.base = await fixture.commit();
  });
  tearDown(() async => fixture.dispose());

  test(
    'a changed library owner includes its maintained part coverage',
    () async {
      final plan = await fixture.plan({
        'lib/first.dart': "part 'fragment.dart';\n${fixtureSource('first', 2)}",
      });
      expect(plan['mode'], 'selected');
      final scope = await _load(fixture, plan);
      expect(scope.sources.values, ['lib/first.dart', 'lib/fragment.dart']);
    },
  );
  test('a changed part includes its owning library coverage', () async {
    final plan = await fixture.plan({
      'lib/fragment.dart':
          "part of 'first.dart';\n${fixtureSource('fragment', 2)}",
    });
    final scope = await _load(fixture, plan);
    expect(scope.sources.values, ['lib/first.dart', 'lib/fragment.dart']);
  });
  test('a sibling part remains required in the same selected library', () async {
    await fixture.write({
      'lib/first.dart':
          "part 'fragment.dart';\npart 'data.dart';\n${fixtureSource('first', 1)}",
    });
    fixture.base = await fixture.commit();
    final plan = await fixture.plan({
      'lib/fragment.dart':
          "part of 'first.dart';\n${fixtureSource('fragment', 2)}",
    });
    final scope = await _load(fixture, plan);
    expect(scope.sources.values.toSet(), {
      'lib/first.dart',
      'lib/fragment.dart',
      'lib/data.dart',
    });
  });
  test('tampering away an executable part cannot narrow the scope', () async {
    final plan = await fixture.plan({
      'lib/first.dart': "part 'fragment.dart';\n${fixtureSource('first', 2)}",
    });
    plan['affectedSources'] = ['lib/first.dart'];
    await expectLater(_load(fixture, plan), throwsFormatException);
  });
}

Future<CoverageScope> _load(
  GitFixture fixture,
  Map<String, Object?> plan,
) async {
  await fixture.write({'coverage-plan.json': jsonEncode(plan)});
  return CoverageScope.load(
    '${fixture.directory.path}/coverage-plan.json',
    root: fixture.directory,
  );
}
