import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'git_fixture.dart';

void main() {
  late GitFixture fixture;
  late String dartExecutable;
  late Directory compiledRunner;
  final runnerPath = '${Directory.current.path}/tool/ci/run_test_plan.dart';
  setUpAll(() async {
    final config =
        jsonDecode(await File('.dart_tool/package_config.json').readAsString())
            as Map<String, dynamic>;
    final flutterRoot = Uri.parse(config['flutterRoot'] as String).toFilePath();
    dartExecutable = '$flutterRoot/bin/cache/dart-sdk/bin/dart';
    compiledRunner = await Directory.systemTemp.createTemp('ci-runner-kernel-');
    addTearDown(() => compiledRunner.delete(recursive: true));
    final compilation = await Process.run(dartExecutable, [
      'compile',
      'kernel',
      runnerPath,
      '--output',
      '${compiledRunner.path}/runner.dill',
    ]);
    expect(compilation.exitCode, 0, reason: '${compilation.stderr}');
  });
  setUp(() async => fixture = await GitFixture.create());
  tearDown(() => fixture.dispose());

  for (final scenario in [
    (selected: true, flutterStatus: 0, coverageStatus: 0, expectedStatus: 0),
    (selected: false, flutterStatus: 0, coverageStatus: 0, expectedStatus: 0),
    (selected: true, flutterStatus: 7, coverageStatus: 0, expectedStatus: 7),
    (selected: true, flutterStatus: 0, coverageStatus: 9, expectedStatus: 9),
  ]) {
    test('runner forwards arguments and exit status: $scenario', () async {
      final changes = scenario.selected
          ? {'lib/first.dart': fixtureSource('first', 9)}
          : {'README.md': 'Updated documentation.\n'};
      final plan = await fixture.plan(changes);
      await fixture.write({
        'plan.json': jsonEncode(plan),
        'bin/flutter': fakeCommand('flutter', scenario.flutterStatus),
        'bin/dart': fakeCommand('dart', scenario.coverageStatus),
      });
      final permissions = await Process.run('chmod', [
        '+x',
        '${fixture.directory.path}/bin/flutter',
        '${fixture.directory.path}/bin/dart',
      ]);
      expect(permissions.exitCode, 0);
      final result = await Process.run(
        dartExecutable,
        ['${compiledRunner.path}/runner.dill', 'plan.json'],
        workingDirectory: fixture.directory.path,
        environment: {
          'PATH':
              '${fixture.directory.path}/bin:${Platform.environment['PATH']}',
        },
      );
      expect(
        result.exitCode,
        scenario.expectedStatus,
        reason: '${result.stderr}',
      );
      expect(await commandArguments(fixture, 'flutter'), [
        'test',
        '--no-pub',
        if (scenario.selected) 'test/first_test.dart',
        '--coverage',
        '--branch-coverage',
      ]);
      final coverageLog = File('${fixture.directory.path}/dart.args');
      if (scenario.flutterStatus != 0) {
        expect(await coverageLog.exists(), isFalse);
      } else {
        expect(await commandArguments(fixture, 'dart'), [
          'run',
          'tool/quality/check_coverage.dart',
          'coverage/lcov.info',
          if (scenario.selected) ...['--scope-plan', 'plan.json'],
        ]);
      }
    });
  }
}

String fakeCommand(String name, int status) =>
    '#!/bin/sh\nprintf "%s\\n" "\$@" > "$name.args"\nexit $status\n';

Future<List<String>> commandArguments(GitFixture fixture, String name) =>
    File('${fixture.directory.path}/$name.args').readAsLines();
