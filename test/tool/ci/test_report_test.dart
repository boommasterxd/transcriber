import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/ci/test_report.dart';
import 'git_fixture.dart';

late Directory directory;
late File report;
const _suite = 'test/first_test.dart';

void main() {
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('test-execution-report-');
    report = File('${directory.path}/tests.json');
  });
  tearDown(() => directory.delete(recursive: true));
  registerProtocolTests();
  registerFileBoundaryTests();
  registerRealRuntimeTests();
}

void registerProtocolTests() {
  test('accepts a successful non-hidden test for the expected suite', () async {
    await writeEvents(successfulEvents());
    await validateReport();
  });
  final mutations = <String, List<Map<String, Object?>> Function()>{
    'no test events': () => [],
    'hidden loader only': () => successfulEvents(hidden: true),
    'all skipped': () => successfulEvents(skipped: true),
    'missing start': () => successfulEvents()..removeAt(0),
    'missing final done': () => successfulEvents()..removeLast(),
    'missing test completion': () => successfulEvents()..removeAt(3),
    'failed completion': () => successfulEvents()..last['success'] = false,
    'unexpected suite': () =>
        successfulEvents()
          ..[1]['suite'] = {'id': 0, 'path': 'test/unexpected_test.dart'},
    'events after done': () => successfulEvents()..add({'type': 'allSuites'}),
    'unknown protocol': () =>
        successfulEvents()..first['protocolVersion'] = 'unknown',
    'non-integer completion ID': () => successfulEvents()..[3]['testID'] = 1.0,
  };
  for (final entry in mutations.entries) {
    test('rejects ${entry.key}', () async {
      await writeEvents(entry.value());
      await expectLater(validateReport(), throwsFormatException);
    });
  }
  test('requires execution in every selected suite', () async {
    await writeEvents(successfulEvents());
    await expectLater(
      validateReport([_suite, 'test/second_test.dart']),
      throwsFormatException,
    );
  });
  test(
    'allows individual skips after real execution in the same suite',
    () async {
      final events = successfulEvents()..removeLast();
      events.addAll([
        {
          'type': 'testStart',
          'test': {
            'id': 2,
            'suiteID': 0,
            'metadata': {'skip': true},
          },
        },
        {
          'type': 'testDone',
          'testID': 2,
          'result': 'success',
          'hidden': false,
          'skipped': true,
        },
        {'type': 'done', 'success': true},
      ]);
      await writeEvents(events);
      await validateReport();
    },
  );
}

void registerFileBoundaryTests() {
  test('rejects a missing report', () async {
    await expectLater(validateReport(), throwsFormatException);
  });
  for (final content in ['{\n', 'null\n', '{}\n']) {
    test('rejects malformed event content: $content', () async {
      await report.writeAsString(content);
      await expectLater(validateReport(), throwsFormatException);
    });
  }
  test('rejects a truncated final record delimiter', () async {
    await writeEvents(successfulEvents());
    final text = await report.readAsString();
    await report.writeAsString(text.substring(0, text.length - 1));
    await expectLater(validateReport(), throwsFormatException);
  });
  test('rejects reports larger than the streaming budget', () async {
    await report.writeAsString(' ' * (32 * 1024 * 1024 + 1));
    await expectLater(validateReport(), throwsFormatException);
  });
}

void registerRealRuntimeTests() {
  test('rejects an actual Flutter all-skipped report', () async {
    final work = await Directory(
      '.dart_tool',
    ).createTemp('flutter-execution-fixture-');
    addTearDown(() => work.delete(recursive: true));
    final source = File('${work.path}/skipped_test.dart');
    await source.writeAsString(
      "import 'package:flutter_test/flutter_test.dart';\n"
      "void main() { test('skipped', () {}, skip: true); }",
    );
    final sdk = await flutterSdkPath();
    final result = await Process.run('$sdk/bin/flutter', [
      'test',
      '--no-pub',
      '--file-reporter=json:${report.path}',
      source.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    await expectLater(
      validateTestReport(report.path, [source.path]),
      throwsFormatException,
    );
  });
  for (final mode in ['success', 'empty', 'skip', 'skip with setup']) {
    test('checks a real Dart reporter for $mode suites', () async {
      final work = await Directory(
        '.dart_tool',
      ).createTemp('execution-fixture-');
      addTearDown(() => work.delete(recursive: true));
      final source = File('${work.path}/example_test.dart');
      final body = switch (mode) {
        'empty' => '',
        'skip' => "test('example', () {}, skip: true);",
        'skip with setup' =>
          "setUpAll(() {}); test('example', () {}, skip: true);",
        _ => "test('example', () {});",
      };
      await source.writeAsString(
        "import 'package:test/test.dart'; void main() { $body }",
      );
      final sdk = await flutterSdkPath();
      final result = await Process.run('$sdk/bin/cache/dart-sdk/bin/dart', [
        'test',
        '--file-reporter=json:${report.path}',
        source.path,
      ]);
      expect(
        result.exitCode,
        mode == 'empty' ? 79 : 0,
        reason: '${result.stderr}',
      );
      final validation = validateTestReport(report.path, [source.path]);
      if (mode == 'success') {
        await validation;
      } else {
        await expectLater(validation, throwsFormatException);
      }
    });
  }
}

Future<void> writeEvents(List<Map<String, Object?>> events) => report
    .writeAsString(events.map(jsonEncode).map((line) => '$line\n').join());

Future<void> validateReport([List<String> suites = const [_suite]]) =>
    validateTestReport(report.path, suites, root: directory.path);

List<Map<String, Object?>> successfulEvents({
  bool hidden = false,
  bool skipped = false,
}) => [
  {'type': 'start', 'protocolVersion': '0.1.1'},
  {
    'type': 'suite',
    'suite': {'id': 0, 'path': _suite},
  },
  {
    'type': 'testStart',
    'test': {
      'id': 1,
      'suiteID': 0,
      'metadata': {'skip': skipped},
    },
  },
  {
    'type': 'testDone',
    'testID': 1,
    'result': 'success',
    'hidden': hidden,
    'skipped': skipped,
  },
  {'type': 'done', 'success': true},
];
