import 'dart:convert';
import 'dart:io';

import 'test_selection.dart';

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length != 1) {
      throw const FormatException('Expected one test plan path.');
    }
    final planPath = arguments.single;
    final plan = await validateTestPlan(
      root: Directory.current.path,
      input: jsonDecode(await File(planPath).readAsString()),
    );
    final tests = (plan['tests']! as List).cast<String>();
    final selected = plan['mode'] == 'selected';
    stdout.writeln('Flutter test mode: ${plan['mode']}. ${plan['reason']}');
    final status = await _run('flutter', [
      'test',
      '--no-pub',
      if (selected) ...tests,
      '--coverage',
      '--branch-coverage',
    ]);
    if (status != 0) {
      exitCode = status;
      return;
    }
    exitCode = await _run('dart', [
      'run',
      'tool/quality/check_coverage.dart',
      'coverage/lcov.info',
      if (selected) ...['--scope-plan', planPath],
    ]);
  } on Exception catch (error) {
    stderr.writeln('Cannot execute test plan: $error');
    exitCode = 1;
  }
}

Future<int> _run(String executable, List<String> arguments) async {
  final process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}
