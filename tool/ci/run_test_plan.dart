import 'dart:convert';
import 'dart:io';

import '../quality/merge_coverage.dart';
import 'test_report.dart';
import 'test_runtime.dart';
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
    final selected = plan['mode'] == 'selected';
    final tests = selected
        ? (plan['tests']! as List).cast<String>()
        : discoverTests(Directory.current.path);
    final runtimes = await TestRuntimes.classify(Directory.current.path, tests);
    stdout.writeln('Test mode: ${plan['mode']}. ${plan['reason']}');
    stdout.writeln(
      'Dart suites: ${runtimes.dart.length}; Flutter suites: ${runtimes.flutter.length}.',
    );
    await _clearCoverage();
    final status = await _runTests(
      runtimes,
      collectCoverage:
          !selected || (plan['affectedSources']! as List).isNotEmpty,
    );
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

Future<int> _runTests(
  TestRuntimes runtimes, {
  required bool collectCoverage,
}) async {
  final reports = <String>[];
  if (runtimes.dart.isNotEmpty) {
    const report = 'coverage/dart/lcov.info';
    await Directory('coverage/dart').create(recursive: true);
    final capture =
        collectCoverage && hasExecutableAppSources(runtimes.dartSources);
    if (!capture) {
      stdout.writeln('Dart runtime: no application coverage expected.');
    }
    final status = await _run('dart', [
      'test',
      '--file-reporter=json:coverage/dart/tests.json',
      if (capture) ...['--coverage-path=$report', '--branch-coverage'],
      ...runtimes.dart,
    ]);
    if (status != 0) return status;
    await validateTestReport('coverage/dart/tests.json', runtimes.dart);
    if (capture) reports.add(report);
  }
  if (runtimes.flutter.isNotEmpty) {
    const report = 'coverage/flutter/lcov.info';
    await Directory('coverage/flutter').create(recursive: true);
    final capture =
        collectCoverage && hasExecutableAppSources(runtimes.flutterSources);
    if (!capture) {
      stdout.writeln('Flutter runtime: no application coverage expected.');
    }
    final status = await _run('flutter', [
      'test',
      '--no-pub',
      '--file-reporter=json:coverage/flutter/tests.json',
      if (capture) ...[
        '--coverage',
        '--branch-coverage',
        '--coverage-path=$report',
      ],
      ...runtimes.flutter,
    ]);
    if (status != 0) return status;
    await validateTestReport('coverage/flutter/tests.json', runtimes.flutter);
    if (capture) reports.add(report);
  }
  if (reports.isEmpty) {
    await File('coverage/lcov.info').parent.create(recursive: true);
    await File('coverage/lcov.info').writeAsString('');
  } else {
    await mergeCoverageFiles(reports, 'coverage/lcov.info');
  }
  return 0;
}

Future<void> _clearCoverage() async {
  final rootType = FileSystemEntity.typeSync('coverage', followLinks: false);
  if (rootType != FileSystemEntityType.notFound &&
      rootType != FileSystemEntityType.directory) {
    throw const FormatException('The coverage root must be a real directory.');
  }
  for (final path in [
    'coverage/lcov.info',
    'coverage/dart',
    'coverage/flutter',
  ]) {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else if (type != FileSystemEntityType.notFound) {
      await File(path).delete();
    }
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
