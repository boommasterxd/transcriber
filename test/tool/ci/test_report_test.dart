import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/ci/test_report.dart';

late Directory directory;
late File report;
const _suite = 'test/first_test.dart';

void main() {
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('test-execution-report-');
    report = File('${directory.path}/tests.json');
  });
  tearDown(() => directory.delete(recursive: true));

  test('requires successful execution in every selected suite', () async {
    await writeEvents(successfulEvents());
    await validateReport();
    await expectLater(
      validateReport([_suite, 'test/second_test.dart']),
      throwsFormatException,
    );
  });

  test('rejects reports containing only skipped or hidden tests', () async {
    for (final events in [
      successfulEvents(skipped: true),
      successfulEvents(hidden: true),
    ]) {
      await writeEvents(events);
      await expectLater(validateReport(), throwsFormatException);
    }
  });

  test('rejects a missing report or a failed or incomplete run', () async {
    await expectLater(validateReport(), throwsFormatException);
    for (final events in [
      successfulEvents()..removeLast(),
      successfulEvents()..last['success'] = false,
    ]) {
      await writeEvents(events);
      await expectLater(validateReport(), throwsFormatException);
    }
  });
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
