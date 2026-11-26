import 'dart:convert';
import 'dart:io';

import 'selection_assets.dart';
import 'selection_git.dart';
import 'selection_graph.dart';

const testPlanVersion = 2;

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
  if ((await git.read(['merge-base', head, checkout])).trim() != head) {
    return _fullPlan(identity, 'The comparison head is absent from checkout.');
  }
  final changed = (await git.changed(
    mergeBase,
    head,
  )).where((file) => !file.startsWith('docs/')).toList();
  if (changed.isEmpty || !changed.every(_isSelectiveChange)) {
    return _fullPlan(identity, 'Global, native, asset, or unknown dependency.');
  }
  final before = await snapshotGraph(git, mergeBase);
  final after = await snapshotGraph(git, head);
  if (before.keys.any(
    (file) => isTestSuite(file) && !after.containsKey(file),
  )) {
    return _fullPlan(
      identity,
      'A deleted or renamed suite requires full test discovery.',
    );
  }
  final execution = checkout == head
      ? after
      : await snapshotGraph(git, checkout);
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
  return _graphPlan(identity, graph, execution, changed);
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
      'flutter_test_config.dart',
      'dart_test.yaml',
    ]),
  );
  return untracked.isNotEmpty;
}

Map<String, Object?> _graphPlan(
  Map<String, Object?> identity,
  ImportGraph graph,
  ImportGraph execution,
  List<String> changed,
) {
  final impacted = reachable(reverseGraph(graph), changed);
  final inventory = execution.keys.where(isTestSuite).toList();
  if (inventory.isEmpty) {
    return _fullPlan(identity, 'The maintained test inventory is empty.');
  }
  final tests = inventory.where(impacted.contains).toList()..sort();
  final dependencies = reachable(graph, tests);
  if (changed.any(
    (file) =>
        (knownAssetOwners.containsKey(file) ||
            (file.startsWith('test/') && !isTestSuite(file))) &&
        !dependencies.contains(file),
  )) {
    return _fullPlan(
      identity,
      'A changed asset or test input has no reliable test dependency.',
    );
  }
  if (changed.any(
    (file) => isTestSuite(file) && !execution.containsKey(file),
  )) {
    return _fullPlan(identity, 'A changed test suite is absent from checkout.');
  }
  return {
    ...identity,
    'mode': tests.isEmpty ? 'no-impact' : 'selected',
    'reason': tests.isEmpty
        ? 'No critical test depends on the changed Dart sources.'
        : 'Transitive dependencies in the base, head and checkout graphs.',
    'tests': tests,
  };
}

bool isTestSuite(String file) =>
    file.startsWith('test/') && file.endsWith('_test.dart');

// Unknown assets, pubspec dependencies, native channels, configuration, and
// CI/test tooling have contracts that Dart imports alone cannot represent.
bool _isSelectiveChange(String file) =>
    knownAssetOwners.containsKey(file) ||
    (file.endsWith('.dart') &&
        !file.endsWith('/flutter_test_config.dart') &&
        (file.startsWith('lib/') || file.startsWith('test/')));

Map<String, Object?> _fullPlan(Map<String, Object?> identity, String reason) =>
    {...identity, 'mode': 'full', 'reason': reason, 'tests': <String>[]};

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
    for (final test in (expected['tests']! as List).cast<String>()) {
      final type = FileSystemEntity.typeSync('$root/$test', followLinks: false);
      if (type != FileSystemEntityType.file) {
        throw const FormatException(
          'A selected test must be a regular file in the checkout.',
        );
      }
    }
  }
  return expected;
}
