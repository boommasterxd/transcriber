import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as path;

import 'selection_git.dart';

typedef ImportGraph = Map<String, Set<String>>;

Future<ImportGraph> snapshotGraph(
  SelectionGit git,
  String revision, {
  ImportGraph? partOwners,
}) async {
  final files = (await git.paths(revision)).where(isGraphSource).toSet();
  if (files.length > 3000) {
    throw const FormatException('Source graph exceeds its resource limit.');
  }
  final contents = await git.readFiles(revision, ['pubspec.yaml', ...files]);
  final pubspec = contents['pubspec.yaml']!;
  final package = RegExp(
    r'^name:\s*([a-z][a-z0-9_]*)\s*$',
    multiLine: true,
  ).firstMatch(pubspec)?.group(1);
  if (package == null) throw const FormatException('Missing package identity.');
  final graph = <String, Set<String>>{};
  var totalSize = 0;
  for (final file in files) {
    final source = contents[file]!;
    totalSize += source.length;
    if (source.length > 2 * 1024 * 1024 || totalSize > 32 * 1024 * 1024) {
      throw const FormatException('Source graph exceeds its size limit.');
    }
    graph[file] = sourceDependencies(
      file,
      source,
      package,
      files,
      partOwners: partOwners,
    );
  }
  return graph;
}

bool isGraphSource(String file) =>
    file.endsWith('.dart') && ['lib/', 'test/', 'tool/'].any(file.startsWith);

Set<String> sourceDependencies(
  String file,
  String source,
  String package,
  Set<String> files, {
  ImportGraph? partOwners,
}) {
  final result = parseString(
    content: source,
    path: file,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  if (result.errors.isNotEmpty) {
    throw FormatException('Cannot parse source graph: $file');
  }
  final dependencies = <String>{};
  for (final directive in result.unit.directives) {
    for (final uri in directiveUris(directive)) {
      final dependency = resolveDependency(file, uri, package);
      if (dependency == null) continue;
      if (!files.contains(dependency)) {
        throw FormatException('Unresolved local dependency in $file');
      }
      dependencies.add(dependency);
      if (directive is PartDirective) {
        partOwners?.putIfAbsent(dependency, () => {}).add(file);
      }
    }
  }
  return dependencies;
}

Iterable<String> directiveUris(Directive directive) sync* {
  if (directive is UriBasedDirective) {
    final value = directive.uri.stringValue;
    if (value == null) throw const FormatException('Nonliteral source URI.');
    yield value;
  }
  if (directive is NamespaceDirective) {
    for (final configuration in directive.configurations) {
      final value = configuration.uri.stringValue;
      if (value == null) throw const FormatException('Nonliteral source URI.');
      yield value;
    }
  }
}

String? resolveDependency(String file, String value, String package) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasQuery || uri.hasFragment) {
    throw const FormatException('Invalid dependency URI.');
  }
  if (uri.scheme == 'dart') return null;
  if (uri.scheme == 'package') {
    if (!uri.path.startsWith('$package/')) return null;
    return 'lib/${uri.path.substring(package.length + 1)}';
  }
  if (uri.hasScheme || uri.hasAuthority || uri.path.startsWith('/')) {
    throw const FormatException('Unsupported dependency URI.');
  }
  final resolved = path.posix.normalize(
    path.posix.join(path.posix.dirname(file), Uri.decodeComponent(uri.path)),
  );
  if (!isGraphSource(resolved)) {
    throw const FormatException('Dependency escapes the source graph.');
  }
  return resolved;
}

ImportGraph unionGraphs(ImportGraph base, ImportGraph head) => {
  for (final file in {...base.keys, ...head.keys})
    file: {...?base[file], ...?head[file]},
};

Set<String> reachable(ImportGraph graph, Iterable<String> initial) {
  final visited = <String>{};
  final queue = initial.toList();
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (!visited.add(file)) continue;
    queue.addAll(graph[file] ?? <String>{});
  }
  return visited;
}

ImportGraph reverseGraph(ImportGraph graph) {
  final reversed = <String, Set<String>>{};
  for (final entry in graph.entries) {
    for (final dependency in entry.value) {
      reversed.putIfAbsent(dependency, () => {}).add(entry.key);
    }
  }
  return reversed;
}
