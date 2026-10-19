import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'git_fixture.dart';

late RunnerFixture runner;

void main() {
  late String dartExecutable;
  late Directory compiledRunner;
  final runnerPath = '${Directory.current.path}/tool/ci/run_test_plan.dart';
  setUpAll(() async {
    final flutterRoot = await flutterSdkPath();
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
  setUp(() async {
    runner = RunnerFixture(
      await GitFixture.create(),
      dartExecutable,
      '${compiledRunner.path}/runner.dill',
    );
    await runner.initialize();
  });
  tearDown(() => runner.fixture.dispose());
  registerRuntimeTests();
  registerNoApplicationCoverageTests();
  registerFailureTests();
  registerExecutionReportTests();
  registerValidationTests();
}

void registerExecutionReportTests() {
  for (final flutter in [false, true]) {
    for (final missing in [false, true]) {
      test(
        'rejects empty execution: Flutter=$flutter missing=$missing',
        () async {
          if (flutter) await runner.useFlutterFirst();
          final plan = await runner.selected();
          await runner.fixture.write({
            'coverage/${flutter ? 'flutter' : 'dart'}/tests.json':
                '{"type":"done","success":true}\n',
          });
          final result = await runner.run(plan, {
            'EMIT_EXECUTION_REPORT': missing ? '0' : '1',
            'SKIP_TESTS': 'true',
          });
          expect(result.exitCode, 1);
          expect(await runner.calls(), [
            flutter ? 'flutter:test' : 'dart:test',
          ]);
          expect(await runner.coverageExists(), isFalse);
        },
      );
    }
  }
}

void registerNoApplicationCoverageTests() {
  for (final flutter in [false, true]) {
    test('test-only scope skips coverage capture: Flutter=$flutter', () async {
      if (flutter) await runner.useFlutterFirst();
      final source = await File(
        '${runner.fixture.directory.path}/test/first_test.dart',
      ).readAsString();
      final plan = await runner.fixture.plan({
        'test/first_test.dart': '$source// Updated test.\n',
      });
      expect(plan['mode'], 'selected');
      expect(plan['affectedSources'], isEmpty);
      final result = await runner.run(plan);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(await runner.calls(), [
        flutter ? 'flutter:test' : 'dart:test',
        'dart:run',
      ]);
      expect(await runner.arguments(flutter ? 'flutter-test' : 'dart-test'), [
        'test',
        if (flutter) '--no-pub',
        '--file-reporter=json:coverage/${flutter ? 'flutter' : 'dart'}/tests.json',
        'test/first_test.dart',
      ]);
      expect(await runner.mergedCoverage(), isEmpty);
      expect(result.stdout, contains('no application coverage expected'));
    });
  }

  test(
    'mixed full plan captures app coverage only in the owning runtime',
    () async {
      await runner.fixture.write({
        'test/first_test.dart': "import 'package:test/test.dart';\n",
      });
      runner.fixture.base = await runner.fixture.commit();
      final result = await runner.runMixed();
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(await runner.calls(), ['dart:test', 'flutter:test', 'dart:run']);
      expect(await runner.arguments('dart-test'), [
        'test',
        '--file-reporter=json:coverage/dart/tests.json',
        'test/first_test.dart',
      ]);
      expect(await runner.mergedCoverage(), contains('/lib/second.dart\n'));
      expect(
        await runner.mergedCoverage(),
        isNot(contains('/lib/first.dart\n')),
      );
    },
  );
}

void registerRuntimeTests() {
  test('selected VM suites invoke Dart once and skip Flutter', () async {
    final plan = await runner.selected();
    expect(plan['tests'], ['test/first_test.dart']);
    final result = await runner.run(plan);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(await runner.calls(), ['dart:test', 'dart:run']);
    expect(await runner.arguments('dart-test'), dartArguments);
    expect(await runner.arguments('dart-run'), coverageArguments);
    expect(await runner.mergedCoverage(), contains('DA:1,1'));
  });
  test('selected Flutter suites skip Dart tests and retain checks', () async {
    await runner.useFlutterFirst();
    final result = await runner.run(await runner.selected());
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(await runner.calls(), ['flutter:test', 'dart:run']);
    expect(await runner.arguments('flutter-test'), flutterArguments);
    expect(await runner.arguments('dart-run'), coverageArguments);
  });
  test(
    'full mixed plans run each runtime once and merge both reports',
    () async {
      final result = await runner.runMixed();
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(await runner.calls(), ['dart:test', 'flutter:test', 'dart:run']);
      expect(await runner.arguments('dart-test'), dartArguments);
      expect(await runner.arguments('flutter-test'), [
        ...flutterArguments.take(flutterArguments.length - 1),
        'test/second_test.dart',
      ]);
      expect(await runner.arguments('dart-run'), coverageArguments.take(3));
      final merged = await runner.mergedCoverage();
      expect(merged, contains('/lib/first.dart\n'));
      expect(merged, contains('/lib/second.dart\n'));
    },
  );
}

void registerFailureTests() {
  test('Dart failures stop Flutter, merge, and coverage checks', () async {
    final plan = await runner.fixture.plan({'README.md': 'Updated.\n'});
    final result = await runner.run(plan, {'DART_TEST_STATUS': '7'});
    expect(result.exitCode, 7);
    expect(await runner.calls(), ['dart:test']);
    expect(await runner.coverageExists(), isFalse);
  });
  test('Flutter failures stop merge and coverage checks', () async {
    await runner.useFlutterFirst();
    final result = await runner.run(await runner.selected(), {
      'FLUTTER_TEST_STATUS': '8',
    });
    expect(result.exitCode, 8);
    expect(await runner.calls(), ['flutter:test']);
    expect(await runner.coverageExists(), isFalse);
  });
  test('coverage checker failures propagate after successful merge', () async {
    final result = await runner.run(await runner.selected(), {
      'COVERAGE_STATUS': '9',
    });
    expect(result.exitCode, 9);
    expect(await runner.calls(), ['dart:test', 'dart:run']);
    expect(await runner.coverageExists(), isTrue);
  });
  for (final flutter in [false, true]) {
    test('missing runtime report rejects stale coverage: $flutter', () async {
      if (flutter) await runner.useFlutterFirst();
      final plan = await runner.selected();
      await runner.fixture.write({
        'coverage/lcov.info': validCoverage,
        'coverage/dart/lcov.info': validCoverage,
        'coverage/flutter/lcov.info': validCoverage,
      });
      final result = await runner.run(plan, {'EMIT_REPORT': '0'});
      expect(result.exitCode, 1);
      expect(await runner.calls(), [flutter ? 'flutter:test' : 'dart:test']);
      expect(await runner.coverageExists(), isFalse);
      for (final runtime in ['dart', 'flutter']) {
        expect(
          await File(
            '${runner.fixture.directory.path}/coverage/$runtime/lcov.info',
          ).exists(),
          isFalse,
        );
      }
    });
  }
}

void registerValidationTests() {
  test(
    'rejects a linked coverage root without deleting external contents',
    () async {
      final plan = await runner.selected();
      final outside = await Directory.systemTemp.createTemp(
        'external-coverage-',
      );
      addTearDown(() => outside.delete(recursive: true));
      final sentinel = File('${outside.path}/dart/sentinel.txt');
      await sentinel.parent.create(recursive: true);
      await sentinel.writeAsString('keep');
      await Link(
        '${runner.fixture.directory.path}/coverage',
      ).create(outside.path);
      final result = await runner.run(plan);
      expect(result.exitCode, 1);
      expect(await runner.calls(), isEmpty);
      expect(await sentinel.readAsString(), 'keep');
    },
  );
  test('invalid plans invoke no binaries', () async {
    final plan = await runner.selected();
    plan['tests'] = <String>[];
    final result = await runner.run(plan);
    expect(result.exitCode, 1);
    expect(await runner.calls(), isEmpty);
  });
  test('stale plans invoke no binaries', () async {
    final plan = await runner.selected();
    await runner.fixture.git(['checkout', '--quiet', runner.fixture.base]);
    final result = await runner.run(plan);
    expect(result.exitCode, 1);
    expect(await runner.calls(), isEmpty);
  });
  test('full plans with an empty inventory reject before execution', () async {
    await runner.fixture.remove('test/first_test.dart');
    await runner.fixture.remove('test/second_test.dart');
    runner.fixture.base = await runner.fixture.commit();
    final plan = await runner.fixture.plan({'README.md': 'Updated.\n'});
    expect(plan['mode'], 'full');
    final result = await runner.run(plan);
    expect(result.exitCode, 1);
    expect(await runner.calls(), isEmpty);
  });
}

const dartArguments = [
  'test',
  '--file-reporter=json:coverage/dart/tests.json',
  '--coverage-path=coverage/dart/lcov.info',
  '--branch-coverage',
  'test/first_test.dart',
];
const flutterArguments = [
  'test',
  '--no-pub',
  '--file-reporter=json:coverage/flutter/tests.json',
  '--coverage',
  '--branch-coverage',
  '--coverage-path=coverage/flutter/lcov.info',
  'test/first_test.dart',
];
const coverageArguments = [
  'run',
  'tool/quality/check_coverage.dart',
  'coverage/lcov.info',
  '--scope-plan',
  'plan.json',
];
const validCoverage =
    'SF:lib/first.dart\nDA:1,1\nBRDA:1,0,0,1\nend_of_record\n';

class RunnerFixture {
  RunnerFixture(this.fixture, this.dartExecutable, this.kernelPath);

  final GitFixture fixture;
  final String dartExecutable;
  final String kernelPath;

  Future<void> initialize() async {
    await fixture.write({
      '.git/info/exclude':
          '/bin/\n/plan.json\n/coverage/\n/*.args\n/calls.log\n',
      'test/first_test.dart':
          "import 'package:test/test.dart';\n"
          "import 'package:transcriber/first.dart';\n",
    });
    fixture.base = await fixture.commit();
    await fixture.write({'bin/dart': fakeCommand, 'bin/flutter': fakeCommand});
    final permissions = await Process.run('chmod', [
      '+x',
      '${fixture.directory.path}/bin/flutter',
      '${fixture.directory.path}/bin/dart',
    ]);
    expect(permissions.exitCode, 0);
  }

  Future<void> useFlutterFirst() async {
    await fixture.write({
      'test/first_test.dart': "import 'package:transcriber/first.dart';\n",
    });
    fixture.base = await fixture.commit();
  }

  Future<Map<String, Object?>> selected() =>
      fixture.plan({'lib/first.dart': fixtureSource('first', 9)});

  Future<ProcessResult> runMixed() async {
    final plan = await fixture.plan({'README.md': 'Updated.\n'});
    expect(plan['mode'], 'full');
    return run(plan, {'FLUTTER_SOURCE': 'lib/second.dart'});
  }

  Future<ProcessResult> run(
    Map<String, Object?> plan, [
    Map<String, String> overrides = const {},
  ]) async {
    await fixture.write({'plan.json': jsonEncode(plan)});
    return Process.run(
      dartExecutable,
      [kernelPath, 'plan.json'],
      workingDirectory: fixture.directory.path,
      environment: {
        'PATH': '${fixture.directory.path}/bin:${Platform.environment['PATH']}',
        'DART_TEST_STATUS': '0',
        'FLUTTER_TEST_STATUS': '0',
        'COVERAGE_STATUS': '0',
        'EMIT_REPORT': '1',
        'EMIT_EXECUTION_REPORT': '1',
        'FLUTTER_SOURCE': 'lib/first.dart',
        ...overrides,
      },
    );
  }

  Future<List<String>> calls() async {
    final log = File('${fixture.directory.path}/calls.log');
    return await log.exists() ? log.readAsLines() : <String>[];
  }

  Future<List<String>> arguments(String name) =>
      File('${fixture.directory.path}/$name.args').readAsLines();

  Future<bool> coverageExists() =>
      File('${fixture.directory.path}/coverage/lcov.info').exists();

  Future<String> mergedCoverage() =>
      File('${fixture.directory.path}/coverage/lcov.info').readAsString();
}

const fakeCommand = r'''#!/bin/sh
name=${0##*/}
action=$1
printf '%s:%s\n' "$name" "$action" >> calls.log
printf '%s\n' "$@" >> "$name-$action.args"
if [ "$name" = dart ] && [ "$action" = run ]; then
  exit "$COVERAGE_STATUS"
fi
if [ "$name" = dart ]; then
  status=$DART_TEST_STATUS
else
  status=$FLUTTER_TEST_STATUS
fi
if [ "$status" != 0 ]; then
  exit "$status"
fi
if [ "$EMIT_EXECUTION_REPORT" = 1 ]; then
  for argument in "$@"; do
    case "$argument" in
      --file-reporter=json:*) execution=${argument#--file-reporter=json:} ;;
    esac
  done
  mkdir -p "${execution%/*}"
  printf '{"type":"start","protocolVersion":"0.1.1"}\n' > "$execution"
  suite=0
  for argument in "$@"; do
    case "$argument" in
      test/*_test.dart)
        printf '{"type":"suite","suite":{"id":%s,"path":"%s"}}\n' "$suite" "$argument" >> "$execution"
        printf '{"type":"testStart","test":{"id":%s,"suiteID":%s,"metadata":{"skip":false}}}\n' "$suite" "$suite" >> "$execution"
        printf '{"type":"testDone","testID":%s,"result":"success","hidden":false,"skipped":%s}\n' "$suite" "${SKIP_TESTS:-false}" >> "$execution"
        suite=$((suite + 1))
        ;;
    esac
  done
  printf '{"type":"done","success":true}\n' >> "$execution"
fi
if [ "$EMIT_REPORT" = 1 ]; then
  for argument in "$@"; do
    case "$argument" in
      --coverage-path=*)
        report=${argument#--coverage-path=}
        mkdir -p "${report%/*}"
        source=lib/first.dart
        if [ "$name" = flutter ]; then
          source=${FLUTTER_SOURCE:-lib/first.dart}
        fi
        printf 'SF:%s\nDA:1,1\nBRDA:1,0,0,1\nend_of_record\n' "$source" > "$report"
        ;;
    esac
  done
fi
exit 0
''';
