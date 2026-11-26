import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'test_report.dart';
import 'test_selection.dart';

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length > 1) {
      throw const FormatException('Expected at most one test plan path.');
    }
    final root = Directory.current.path;
    final tests = await _resolveTests(root, arguments.firstOrNull);
    if (tests != null) {
      exitCode = await _runTests(tests);
    }
  } on Exception catch (error) {
    stderr.writeln('Cannot execute test plan: $error');
    exitCode = 1;
  }
}

Future<List<String>?> _resolveTests(String root, String? planPath) async {
  if (planPath == null) return _discoverTests(root);
  final plan = await validateTestPlan(
    root: root,
    input: jsonDecode(await File(planPath).readAsString()),
  );
  stdout.writeln('Test mode: ${plan['mode']}. ${plan['reason']}');
  return switch (plan['mode']) {
    'no-impact' => null,
    'selected' => (plan['tests']! as List).cast<String>(),
    'full' => _discoverTests(root),
    _ => throw const FormatException('Unknown test plan mode.'),
  };
}

List<String> _discoverTests(String root) {
  final directory = Directory(path.join(root, 'test'));
  final entries = directory.listSync(recursive: true, followLinks: false);
  if (entries.any((entry) => entry is Link)) {
    throw const FormatException('The test inventory contains symbolic links.');
  }
  return entries
      .whereType<File>()
      .map((file) => path.relative(file.path, from: root))
      .where(isTestSuite)
      .toList()
    ..sort();
}

Future<int> _runTests(List<String> tests) async {
  if (tests.isEmpty) {
    throw const FormatException('The maintained Dart test inventory is empty.');
  }
  final temporary = await Directory.systemTemp.createTemp('transcriber-tests-');
  try {
    final report = path.join(temporary.path, 'tests.json');
    final process = await Process.start('flutter', [
      'test',
      '--no-pub',
      '--reporter=expanded',
      '--file-reporter=json:$report',
      ...tests,
    ], mode: ProcessStartMode.inheritStdio);
    final status = await process.exitCode;
    if (status == 0) await validateTestReport(report, tests);
    return status;
  } finally {
    await temporary.delete(recursive: true);
  }
}
