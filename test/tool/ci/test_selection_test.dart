import 'package:test/test.dart';

import '../../../tool/ci/test_selection.dart';
import 'git_fixture.dart';

void main() {
  late GitFixture fixture;
  setUp(() async => fixture = await GitFixture.create());
  tearDown(() => fixture.dispose());

  test(
    'selects tests through a transitive import and a renamed part',
    () async {
      await fixture.write({
        'lib/first.dart': "part 'fragment.dart';\n",
        'lib/fragment.dart':
            "part of 'first.dart';\n${fixtureSource('fragment', 1)}",
        'test/support.dart': "export 'package:transcriber/first.dart';\n",
        'test/first_test.dart': "import 'support.dart';\n",
      });
      fixture.base = await fixture.commit();
      await fixture.git(['mv', 'lib/fragment.dart', 'lib/renamed.dart']);
      final plan = await fixture.plan({
        'lib/first.dart': "part 'renamed.dart';\n",
        'docs/architecture.md': '# Updated architecture\n',
      });
      expect(plan['mode'], 'selected');
      expect(plan['tests'], ['test/first_test.dart']);
    },
  );

  test('selects changes to a test or its shared fixture', () async {
    await fixture.write({
      'test/support.dart': "export '../lib/first.dart';\n",
      'test/first_test.dart': "import 'support.dart';\n",
    });
    fixture.base = await fixture.commit();
    final plan = await fixture.plan({
      'test/support.dart': "export '../lib/second.dart';\n",
      'test/second_test.dart':
          "import '../lib/second.dart';\n// Test change.\n",
    });
    expect(plan['mode'], 'selected');
    expect(plan['tests'], ['test/first_test.dart', 'test/second_test.dart']);
  });

  test(
    'validates no test impact for independent Dart code',
    () => _verifyNoImpactPlan(fixture),
  );

  test('falls back when a test disappears or a global input changes', () async {
    await fixture.remove('test/first_test.dart');
    final deletion = await fixture.plan({});
    expect(deletion['mode'], 'full');
    fixture.base = deletion['head']! as String;
    final global = await fixture.plan({'test/flutter_test_config.dart': ''});
    expect(global['mode'], 'full');
  });

  test('includes consumers from the simulated merge checkout', () async {
    await fixture.git(['switch', '-c', 'topic']);
    final topic = await fixture.plan({
      'lib/first.dart': fixtureSource('first', 3),
    });
    final head = topic['head']! as String;
    await fixture.git(['switch', 'main']);
    await fixture.write({
      'test/second_test.dart': "import '../lib/first.dart';\n",
    });
    final base = await fixture.commit();
    await fixture.git(['merge', '--no-edit', 'topic']);
    final plan = await createTestPlan(
      root: fixture.directory.path,
      base: base,
      head: head,
    );
    expect(plan['tests'], ['test/first_test.dart', 'test/second_test.dart']);
    expect(plan['checkout'], await fixture.git(['rev-parse', 'HEAD']));
  });

  test(
    'rejects an invented no-impact selection on a relevant change',
    () async {
      final plan = await fixture.plan({
        'lib/first.dart': fixtureSource('first', 3),
      });
      final head = await fixture.git(['rev-parse', 'HEAD']);
      await expectLater(
        validateTestPlan(
          root: fixture.directory.path,
          input: {...plan, 'mode': 'no-impact', 'tests': <String>[]},
          revisions: (base: fixture.base, head: head, checkout: head),
        ),
        throwsFormatException,
      );
    },
  );
}

Future<void> _verifyNoImpactPlan(GitFixture fixture) async {
  final plan = await fixture.plan({
    'lib/independent.dart': fixtureSource('independent', 1),
  });
  expect(plan['mode'], 'no-impact');
  expect(plan['tests'], isEmpty);
  final head = await fixture.git(['rev-parse', 'HEAD']);
  expect(
    await validateTestPlan(
      root: fixture.directory.path,
      input: plan,
      revisions: (base: fixture.base, head: head, checkout: head),
    ),
    plan,
  );
  await expectLater(
    validateTestPlan(
      root: fixture.directory.path,
      input: plan,
      revisions: (base: head, head: head, checkout: head),
    ),
    throwsFormatException,
  );
}
