import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'selection_git_objects.dart';

class SelectionGit {
  SelectionGit(this.root);

  final String root;

  Future<String> read(List<String> arguments) async =>
      utf8.decode(await _run(arguments));

  Future<Map<String, String>> readFiles(
    String revision,
    List<String> paths,
  ) async {
    if (!isCommitSha(revision) ||
        paths.length > 3001 ||
        paths.any((path) => path.isEmpty || path.contains('\u0000'))) {
      throw const FormatException('Invalid Git source request.');
    }
    if (paths.isEmpty) return {};
    final queries = paths.map((path) => '$revision:$path').join('\u0000');
    final data = await _run([
      'cat-file',
      '--batch',
      '-z',
    ], input: utf8.encode('$queries\u0000'));
    return parseGitFiles(data, paths);
  }

  Future<Uint8List> _run(List<String> arguments, {List<int>? input}) async {
    final process = await Process.start(
      'git',
      arguments,
      workingDirectory: root,
    );
    final timer = Timer(const Duration(seconds: 30), () => process.kill());
    try {
      final output = _collect(process);
      final errors = process.stderr.drain<void>();
      if (input != null) process.stdin.add(input);
      final results = await Future.wait<Object?>([
        output,
        errors,
        process.exitCode,
        process.stdin.close(),
      ]);
      if (results[2] != 0) {
        throw const FormatException('Git history is unavailable or too large.');
      }
      return results.first! as Uint8List;
    } finally {
      timer.cancel();
    }
  }

  Future<List<String>> paths(String revision) async {
    final raw = await read(['ls-tree', '-r', '--name-only', '-z', revision]);
    return splitPaths(raw);
  }

  Future<List<String>> changed(String base, String head) async {
    final raw = await read([
      'diff',
      '--name-only',
      '--no-renames',
      '-z',
      base,
      head,
      '--',
    ]);
    return splitPaths(raw);
  }
}

Future<Uint8List> _collect(Process process) async {
  final buffer = BytesBuilder(copy: false);
  var size = 0;
  await for (final chunk in process.stdout) {
    size += chunk.length;
    if (size > 32 * 1024 * 1024) {
      process.kill();
      throw const FormatException('Git output exceeds its resource limit.');
    }
    buffer.add(chunk);
  }
  return buffer.takeBytes();
}

List<String> splitPaths(String raw) {
  if (raw.isEmpty) return [];
  if (!raw.endsWith('\u0000')) {
    throw const FormatException('Incomplete Git path list.');
  }
  return raw.substring(0, raw.length - 1).split('\u0000');
}

bool isCommitSha(String value) =>
    RegExp(r'^(?:[a-fA-F0-9]{40}|[a-fA-F0-9]{64})$').hasMatch(value) &&
    !RegExp(r'^0+$').hasMatch(value);
