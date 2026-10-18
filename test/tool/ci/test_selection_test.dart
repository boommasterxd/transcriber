import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/ci/test_selection.dart';
import 'git_fixture.dart';

late GitFixture fixture;

void main() {
  setUp(() async => fixture = await GitFixture.create());
  tearDown(() async => fixture.dispose());
  registerDependencyTests();
  registerChangedFileTests();
  registerFallbackTests();
  registerValidationTests();
  registerCheckoutTests();
}

void registerDependencyTests() {
  test('selects only the test importing an affected source', () async {
    final plan = await fixture.plan({
      'lib/first.dart': fixtureSource('first', 3),
    });
    expectSelected(plan, ['test/first_test.dart']);
    expect(plan['affectedSources'], ['lib/first.dart']);
    expect(plan['mergeBase'], fixture.base);
    expect(plan['head'], await fixture.git(['rev-parse', 'HEAD']));
  });

  test('keeps a selection for mixed docs and production changes', () async {
    final plan = await fixture.plan({
      'lib/first.dart': fixtureSource('first', 15),
      'docs/architecture.md': '# Updated architecture\n',
    });
    expectSelected(plan, ['test/first_test.dart']);
  });

  test('follows transitive dependencies and sorts selected tests', () async {
    await fixture.write({
      'lib/shared.dart': fixtureSource('shared', 1),
      'lib/first.dart': "export 'shared.dart';\n",
      'lib/second.dart': "import 'first.dart';\n",
    });
    fixture.base = await fixture.commit();
    final plan = await fixture.plan({
      'lib/shared.dart': fixtureSource('shared', 2),
    });
    expectSelected(plan, ['test/first_test.dart', 'test/second_test.dart']);
    expect(plan['affectedSources'], ['lib/shared.dart']);
  });

  final directives = {
    'conditional import':
        "import 'second.dart' if (dart.library.io) 'target.dart';\n",
    'conditional export':
        "export 'second.dart' if (dart.library.io) 'target.dart';\n",
    'part': "part 'target.dart';\n",
  };
  for (final entry in directives.entries) {
    test('follows ${entry.key} dependencies', () async {
      await fixture.write({
        'lib/first.dart': entry.value,
        'lib/target.dart': fixtureSource('target', 1),
      });
      fixture.base = await fixture.commit();
      final plan = await fixture.plan({
        'lib/target.dart': fixtureSource('target', 2),
      });
      expectSelected(plan, ['test/first_test.dart']);
      expect(plan['affectedSources'], [
        if (entry.key == 'part') 'lib/first.dart',
        'lib/target.dart',
      ]);
    });
  }
}

void registerChangedFileTests() {
  test('selects a changed test without production source changes', () async {
    final plan = await fixture.plan({
      'test/second_test.dart': "import '../lib/second.dart';\n// Updated.\n",
    });
    expectSelected(plan, ['test/second_test.dart']);
  });

  test('follows dependencies through a shared test helper', () async {
    await fixture.write({
      'test/helper.dart': "export '../lib/first.dart';\n",
      'test/first_test.dart': "import 'helper.dart';\n",
    });
    fixture.base = await fixture.commit();
    final plan = await fixture.plan({
      'test/helper.dart': "export '../lib/second.dart';\n",
    });
    expectSelected(plan, ['test/first_test.dart']);
  });

  test('selects surviving tests after deleting a source dependency', () async {
    await fixture.remove('lib/first.dart');
    final plan = await fixture.plan({
      'test/first_test.dart': "import '../lib/second.dart';\n",
    });
    expectSelected(plan, ['test/first_test.dart']);
  });

  test('tracks both sides of a source rename', () async {
    await fixture.git(['mv', 'lib/first.dart', 'lib/renamed.dart']);
    final plan = await fixture.plan({
      'test/first_test.dart': "import 'package:transcriber/renamed.dart';\n",
    });
    expectSelected(plan, ['test/first_test.dart']);
  });

  test('does not return deleted tests', () async {
    await fixture.remove('test/first_test.dart');
    final plan = await fixture.plan({
      'lib/second.dart': fixtureSource('second', 4),
    });
    expectSelected(plan, ['test/second_test.dart']);
  });
}

void registerFallbackTests() {
  for (final path in [
    'README.md',
    'pubspec.yaml',
    'tool/helper.dart',
    'test/flutter_test_config.dart',
    'test/sub/flutter_test_config.dart',
  ]) {
    test('falls back to full execution for $path changes', () async {
      final plan = await fixture.plan({
        path: '// Changed configuration.\n',
        'lib/first.dart': fixtureSource('first', 17),
      });
      expect(plan['mode'], 'full');
    });
  }

  test('falls back to full execution for an unreferenced source', () async {
    final plan = await fixture.plan({
      'lib/unused.dart': fixtureSource('unused', 1),
    });
    expect(plan['mode'], 'full');
  });

  test('falls back for an unmapped test fixture in a mixed change', () async {
    await fixture.write({
      'test/fixtures/input.dart': 'const input = 1;\n',
      'test/second_test.dart':
          "import 'dart:io';\nimport '../lib/second.dart';\n"
          "void main() { File('test/fixtures/input.dart').readAsStringSync(); }\n",
    });
    fixture.base = await fixture.commit();
    final plan = await fixture.plan({
      'lib/first.dart': fixtureSource('first', 19),
      'test/fixtures/input.dart': 'const input = 2;\n',
    });
    expect(plan['mode'], 'full');
  });

  test('falls back to full execution with unavailable history', () async {
    final plan = await createTestPlan(
      root: fixture.directory.path,
      base: 'f' * 40,
      head: fixture.base,
    );
    expect(plan['mode'], 'full');
  });

  test('falls back to full execution without changed files', () async {
    final plan = await createTestPlan(
      root: fixture.directory.path,
      base: fixture.base,
      head: fixture.base,
    );
    expect(plan['mode'], 'full');
  });

  for (final source in ['const first = 18;\n', 'int first() => 18;\n']) {
    test(
      'falls back when the scope lacks coverage metric denominators',
      () async {
        final plan = await fixture.plan({'lib/first.dart': source});
        expect(plan['mode'], 'full');
      },
    );
  }
}

void registerValidationTests() {
  test('validates a freshly generated selection', () async {
    final plan = await fixture.plan({
      'lib/first.dart': fixtureSource('first', 5),
    });
    final validated = await validateTestPlan(
      root: fixture.directory.path,
      input: plan,
    );
    expect(validated, plan);
  });

  test('rejects an incomplete selection even when every path exists', () async {
    await fixture.write({'lib/second.dart': "export 'first.dart';\n"});
    fixture.base = await fixture.commit();
    final plan = await fixture.plan({
      'lib/first.dart': fixtureSource('first', 6),
    });
    plan['tests'] = ['test/first_test.dart'];
    await expectLater(
      validateTestPlan(root: fixture.directory.path, input: plan),
      throwsFormatException,
    );
  });

  final invalidValues = <String, Object?>{
    'schemaVersion': 2,
    'mode': 'skip',
    'head': '--help',
    'mergeBase': '../outside',
    'tests': ['../outside_test.dart'],
    'affectedSources': ['lib/../../outside.dart'],
  };
  for (final entry in invalidValues.entries) {
    test('rejects invalid ${entry.key}', () async {
      final plan = await fixture.plan({
        'lib/first.dart': fixtureSource('first', 7),
      });
      plan[entry.key] = entry.value;
      await expectLater(
        validateTestPlan(root: fixture.directory.path, input: plan),
        throwsFormatException,
      );
    });
  }

  test('rejects non-object plans', () async {
    await expectLater(
      validateTestPlan(root: fixture.directory.path, input: <Object?>[]),
      throwsFormatException,
    );
  });

  test(
    'rejects a selected test that disappears from the working tree',
    () async {
      final plan = await fixture.plan({
        'lib/first.dart': fixtureSource('first', 8),
      });
      await fixture.remove('test/first_test.dart');
      await expectLater(
        validateTestPlan(root: fixture.directory.path, input: plan),
        throwsFormatException,
      );
      expect(
        File('${fixture.directory.path}/test/first_test.dart').existsSync(),
        isFalse,
      );
    },
  );
}

void expectSelected(Map<String, Object?> plan, List<String> tests) {
  expect(plan['schemaVersion'], 1);
  expect(plan['mode'], 'selected');
  expect(plan['reason'], isA<String>());
  expect(plan['tests'], tests);
}

void registerCheckoutTests() {
  test('rejects a plan after the checkout advances to a new commit', () async {
    final plan = await fixture.plan({
      'lib/first.dart': fixtureSource('first', 10),
    });
    await fixture.write({'lib/second.dart': fixtureSource('second', 11)});
    await fixture.commit();
    await expectLater(
      validateTestPlan(root: fixture.directory.path, input: plan),
      throwsFormatException,
    );
  });

  test('falls back to full execution for dirty production sources', () async {
    final plan = await fixture.plan({
      'lib/first.dart': fixtureSource('first', 12),
    });
    await fixture.write({'lib/second.dart': fixtureSource('second', 13)});
    final dirtyPlan = await createTestPlan(
      root: fixture.directory.path,
      base: fixture.base,
      head: plan['head']! as String,
    );
    expect(dirtyPlan['mode'], 'full');
    await expectLater(
      validateTestPlan(root: fixture.directory.path, input: plan),
      throwsFormatException,
    );
  });

  test('rejects a forged checkout identity', () async {
    final plan = await fixture.plan({
      'lib/first.dart': fixtureSource('first', 14),
    });
    plan['checkout'] = fixture.base;
    await expectLater(
      validateTestPlan(root: fixture.directory.path, input: plan),
      throwsFormatException,
    );
  });

  test('falls back to full execution for untracked source files', () async {
    final plan = await fixture.plan({
      'lib/first.dart': fixtureSource('first', 16),
    });
    await fixture.write({'lib/untracked.dart': fixtureSource('untracked', 1)});
    final dirtyPlan = await createTestPlan(
      root: fixture.directory.path,
      base: fixture.base,
      head: plan['head']! as String,
    );
    expect(dirtyPlan['mode'], 'full');
  });
}
