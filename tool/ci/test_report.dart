import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

Future<void> validateTestReport(
  String reportPath,
  List<String> tests, {
  String? root,
}) async {
  const limit = 32 * 1024 * 1024;
  final file = File(reportPath);
  if (!await file.exists() || await file.length() > limit) {
    throw const FormatException(
      'The runtime execution report is missing or too large.',
    );
  }
  final report = _ExecutionReport(root ?? Directory.current.path, tests);
  var size = 0;
  var lastByte = -1;
  final lines = file
      .openRead()
      .map((bytes) {
        size += bytes.length;
        if (size > limit) {
          throw const FormatException('Execution report exceeds its limit.');
        }
        if (bytes.isNotEmpty) lastByte = bytes.last;
        return bytes;
      })
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  await for (final line in lines) {
    report.add(line);
  }
  if (lastByte != 10) {
    throw const FormatException('Truncated runtime execution report.');
  }
  report.verifyComplete();
}

class _ExecutionReport {
  _ExecutionReport(this.root, List<String> tests)
    : expected = tests.map((test) => _absolute(root, test)).toSet() {
    if (expected.isEmpty || expected.length != tests.length) {
      throw const FormatException('Expected nonempty unique runtime suites.');
    }
  }

  final String root;
  final Set<String> expected;
  final _suites = <int, String>{};
  final _pending = <int, ({int suite, bool skipped})>{};
  final _startedTests = <int>{};
  final _executed = <String>{};
  var _started = false;
  var _done = false;

  void add(String line) {
    final event = jsonDecode(line);
    if (_done || event is! Map<String, dynamic> || event['type'] is! String) {
      throw const FormatException('Malformed runtime execution event.');
    }
    final type = event['type'] as String;
    if (!_started && type != 'start') {
      throw const FormatException('The execution report has no start event.');
    }
    switch (type) {
      case 'start':
        if (_started || event['protocolVersion'] != '0.1.1') {
          throw const FormatException('Invalid execution start event.');
        }
        _started = true;
      case 'suite':
        _suite(event['suite']);
      case 'testStart':
        _testStart(event['test']);
      case 'testDone':
        _testDone(event);
      case 'done':
        if (event['success'] != true || _pending.isNotEmpty) {
          throw const FormatException(
            'The runtime did not finish successfully.',
          );
        }
        _done = true;
      case 'allSuites' || 'group' || 'print' || 'debug':
        break;
      default:
        throw const FormatException('Unexpected runtime execution event.');
    }
  }

  void _suite(Object? suite) {
    if (suite is! Map<String, dynamic> ||
        suite['id'] is! int ||
        (suite['id'] as int) < 0 ||
        suite['path'] is! String ||
        _suites.containsKey(suite['id'])) {
      throw const FormatException('Invalid runtime suite event.');
    }
    final source = _absolute(root, suite['path'] as String);
    if (!expected.contains(source)) {
      throw const FormatException('An unexpected suite was executed.');
    }
    _suites[suite['id'] as int] = source;
  }

  void _testStart(Object? test) {
    if (test is! Map<String, dynamic> ||
        test['id'] is! int ||
        test['suiteID'] is! int ||
        !_suites.containsKey(test['suiteID']) ||
        test['metadata'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid runtime test start event.');
    }
    final id = test['id'] as int;
    final skip = (test['metadata'] as Map<String, dynamic>)['skip'];
    if (id < 0 || !_startedTests.add(id) || skip is! bool) {
      throw const FormatException('Duplicate or invalid runtime test.');
    }
    _pending[id] = (suite: test['suiteID'] as int, skipped: skip);
  }

  void _testDone(Map<String, dynamic> event) {
    if (event['testID'] is! int) {
      throw const FormatException('Invalid runtime completion identifier.');
    }
    final test = _pending.remove(event['testID']);
    if (test == null ||
        event['hidden'] is! bool ||
        event['skipped'] is! bool ||
        event['result'] != 'success') {
      throw const FormatException(
        'Invalid or unsuccessful runtime test completion.',
      );
    }
    if (event['hidden'] == false &&
        event['skipped'] == false &&
        !test.skipped) {
      _executed.add(_suites[test.suite]!);
    }
  }

  void verifyComplete() {
    if (!_started || !_done || !expected.every(_executed.contains)) {
      throw const FormatException(
        'A runtime suite executed no successful tests.',
      );
    }
  }
}

String _absolute(String root, String file) =>
    path.normalize(path.isAbsolute(file) ? file : path.join(root, file));
