import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/quality/check_code_quality.dart';

void main() {
  late Directory directory;
  late String report;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('quality-metrics-');
    report = '${directory.path}/metrics.json';
  });
  tearDown(() => directory.deleteSync(recursive: true));

  List<String> check(List<Map<String, Object>> metrics) {
    File(report).writeAsStringSync(
      jsonEncode({
        'records': [
          {
            'path': 'lib/fixture.dart',
            'functions': {
              'run': {'metrics': metrics},
            },
          },
        ],
      }),
    );
    return checkDclMetrics(report);
  }

  final boundary = [
    {'metricsId': 'cyclomatic-complexity', 'value': 20},
    {'metricsId': 'lines-of-code', 'value': 100},
    {'metricsId': 'maximum-nesting-level', 'value': 4},
  ];
  test('accepts every DCL metric at its exact unchanged limit', () {
    expect(check(boundary), isEmpty);
  });
  for (final metric in boundary) {
    final id = metric['metricsId']! as String;
    test('fails closed when DCL omits $id', () {
      expect(check(boundary.where((entry) => entry != metric).toList()), [
        contains('$id is missing'),
      ]);
    });
    test('fails $id above its limit', () {
      final above = [
        for (final entry in boundary)
          if (entry == metric)
            {...entry, 'value': (entry['value']! as int) + 1}
          else
            entry,
      ];
      expect(check(above), [contains('$id is ')]);
    });
  }
  test('fails closed when a metric is duplicated or negative', () {
    expect(check([...boundary, boundary.first]), [contains('is duplicated')]);
    expect(
      check([
        {...boundary.first, 'value': -1},
        ...boundary.skip(1),
      ]),
      [contains('is invalid')],
    );
  });
  test('an empty DCL report cannot pass quality enforcement', () {
    File(report).writeAsStringSync('{"records":[]}');
    expect(checkDclMetrics(report), ['DCL reported no source records.']);
  });
}
