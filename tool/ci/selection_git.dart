import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SelectionGit {
  SelectionGit(this.root);

  final String root;

  Future<String> read(List<String> arguments) async {
    final process = await Process.start(
      'git',
      arguments,
      workingDirectory: root,
    );
    final timer = Timer(const Duration(seconds: 30), () => process.kill());
    try {
      final output = _collect(process);
      final errors = process.stderr.drain<void>();
      final text = await output;
      await errors;
      if (await process.exitCode != 0) {
        throw const FormatException('Git history is unavailable or too large.');
      }
      return text;
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

Future<String> _collect(Process process) async {
  final buffer = StringBuffer();
  var size = 0;
  await for (final chunk in process.stdout.transform(utf8.decoder)) {
    size += chunk.length;
    if (size > 32 * 1024 * 1024) {
      process.kill();
      throw const FormatException('Git output exceeds its resource limit.');
    }
    buffer.write(chunk);
  }
  return buffer.toString();
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
