import 'dart:convert';
import 'dart:io';

import 'selection_assets.dart';
import 'selection_git.dart';
import 'selection_graph.dart';
import 'selection_metrics.dart';

const testPlanVersion = 1;

Future<Map<String, Object?>> createTestPlan({
  required String root,
  required String base,
  required String head,
}) async {
  final identity = <String, Object?>{
    'schemaVersion': testPlanVersion,
    'base': base,
    'mergeBase': '',
    'head': head,
    'checkout': '',
  };
  try {
    final git = SelectionGit(root);
    identity['checkout'] = (await git.read(['rev-parse', 'HEAD'])).trim();
    if (!isCommitSha(base) || !isCommitSha(head)) {
      return _fullPlan(identity, 'Invalid or missing comparison revisions.');
    }
    return await _select(git, identity);
  } on Exception {
    return _fullPlan(
      identity,
      'Incomplete history or unreliable source graph.',
    );
  }
}

Future<Map<String, Object?>> _select(
  SelectionGit git,
  Map<String, Object?> identity,
) async {
  final base = identity['base']! as String;
  final head = identity['head']! as String;
  final checkout = identity['checkout']! as String;
  if (await _checkoutIsDirty(git)) {
    return _fullPlan(
      identity,
      'The execution checkout has uncommitted inputs.',
    );
  }
  final mergeBase = (await git.read(['merge-base', base, head])).trim();
  if (!isCommitSha(mergeBase)) {
    throw const FormatException('Invalid merge base.');
  }
  identity['mergeBase'] = mergeBase;
  final changed = (await git.changed(
    mergeBase,
    head,
  )).where((file) => !file.startsWith('docs/')).toList();
  if (changed.isEmpty || !changed.every(_isSelectiveChange)) {
    return _fullPlan(identity, 'Global, native, asset, or unknown dependency.');
  }
  final before = await snapshotGraph(git, mergeBase);
  final partOwners = <String, Set<String>>{};
  final after = await snapshotGraph(
    git,
    head,
    partOwners: checkout == head ? partOwners : null,
  );
  if (before.keys.any(
    (file) =>
        file.startsWith('test/') &&
        file.endsWith('_test.dart') &&
        !after.containsKey(file),
  )) {
    return _fullPlan(
      identity,
      'A deleted or renamed test suite requires full production coverage.',
    );
  }
  final execution = checkout == head
      ? after
      : await snapshotGraph(git, checkout, partOwners: partOwners);
  final graph = unionGraphs(unionGraphs(before, after), execution);
  if (changed.any(knownAssetOwners.containsKey) &&
      !addAssetDependencies(
        graph,
        execution,
        changed,
        (await git.paths(checkout)).toSet(),
      )) {
    return _fullPlan(
      identity,
      'A known asset dependency is missing from the checkout.',
    );
  }
  final plan = _graphPlan(identity, graph, execution, changed, partOwners);
  if (plan['mode'] == 'selected' &&
      !await supportsScopedMetrics(
        git,
        checkout,
        (plan['affectedSources']! as List).cast<String>(),
      )) {
    return _fullPlan(
      identity,
      'Restricted coverage metrics cannot be established.',
    );
  }
  return plan;
}

Future<bool> _checkoutIsDirty(SelectionGit git) async {
  if (await git.read(['diff', '--name-only', '-z', 'HEAD', '--']) != '') {
    return true;
  }
  final untracked = splitPaths(
    await git.read([
      'ls-files',
      '--others',
      '--exclude-standard',
      '-z',
      '--',
      'lib',
      'test',
      'tool',
      'assets',
      'android',
    ]),
  );
  return untracked.isNotEmpty;
}

Map<String, Object?> _graphPlan(
  Map<String, Object?> identity,
  ImportGraph graph,
  ImportGraph execution,
  List<String> changed,
  ImportGraph partOwners,
) {
  final impacted = reachable(reverseGraph(graph), changed);
  final tests =
      execution.keys
          .where(
            (file) =>
                file.startsWith('test/') &&
                file.endsWith('_test.dart') &&
                impacted.contains(file),
          )
          .toList()
        ..sort();
  if (tests.isEmpty) {
    return _fullPlan(identity, 'No reliable nonempty impacted test selection.');
  }
  final covered = reachable(graph, tests);
  if (changed.any(
    (file) => knownAssetOwners.containsKey(file) && !covered.contains(file),
  )) {
    return _fullPlan(
      identity,
      'A changed asset has no selected consumer test.',
    );
  }
  if (changed.any(
    (file) =>
        file.startsWith('test/') &&
        !file.endsWith('_test.dart') &&
        !covered.contains(file),
  )) {
    return _fullPlan(
      identity,
      'A changed test input has no reliable import edge.',
    );
  }
  final production = reachable(
    unionGraphs(partOwners, reverseGraph(partOwners)),
    changed,
  ).where((file) => file.startsWith('lib/'));
  if (production.any(
    (file) => execution.containsKey(file) && !covered.contains(file),
  )) {
    return _fullPlan(
      identity,
      'An affected production source has no selected test.',
    );
  }
  final sources =
      production
          .where(
            (file) => file.startsWith('lib/') && execution.containsKey(file),
          )
          .toList()
        ..sort();
  return {
    ...identity,
    'mode': 'selected',
    'reason': 'Transitive dependencies in the base and head source graphs.',
    'tests': tests,
    'affectedSources': sources,
  };
}

// Unknown assets, pubspec dependencies, native channels, configuration, and
// CI/test tooling have contracts that Dart imports alone cannot represent.
bool _isSelectiveChange(String file) =>
    knownAssetOwners.containsKey(file) ||
    (file.endsWith('.dart') &&
        !file.endsWith('/flutter_test_config.dart') &&
        (file.startsWith('lib/') || file.startsWith('test/')));

Map<String, Object?> _fullPlan(Map<String, Object?> identity, String reason) =>
    {
      ...identity,
      'mode': 'full',
      'reason': reason,
      'tests': <String>[],
      'affectedSources': <String>[],
    };

Future<Map<String, Object?>> validateTestPlan({
  required String root,
  required Object? input,
}) async {
  if (input is! Map<String, dynamic> ||
      input['schemaVersion'] != testPlanVersion ||
      input['base'] is! String ||
      input['head'] is! String) {
    throw const FormatException('Invalid test plan schema.');
  }
  final expected = await createTestPlan(
    root: root,
    base: input['base'] as String,
    head: input['head'] as String,
  );
  if (jsonEncode(input) != jsonEncode(expected)) {
    throw const FormatException(
      'Test plan does not match the complete Git diff.',
    );
  }
  if (expected['mode'] == 'selected') {
    final git = SelectionGit(root);
    final checkedHead = (await git.read([
      'merge-base',
      expected['head']! as String,
      'HEAD',
    ])).trim();
    if (checkedHead != expected['head']) {
      throw const FormatException('Test plan does not describe this checkout.');
    }
    for (final test in (expected['tests']! as List).cast<String>()) {
      if (!File('$root/$test').existsSync()) {
        throw const FormatException(
          'A selected test is missing from the checkout.',
        );
      }
    }
  }
  return expected;
}
