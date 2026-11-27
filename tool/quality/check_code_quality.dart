import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;

import 'dart_function_metrics.dart';
import 'parameter_count.dart';

const _fileLengthLimit = 500;
const _driftAdapter = 'lib/data/database/app_database.g.dart';
const _generatedHeader = '// GENERATED CODE - DO NOT MODIFY BY HAND';
const _databasePart = "part of 'app_database.dart';";
const _metricLimits = <String, num>{
  'cyclomatic-complexity': 20,
  'lines-of-code': 100,
  'maximum-nesting-level': 4,
};

void main(List<String> arguments) {
  final metricsPath = _option(arguments, '--metrics');
  if (metricsPath == null) {
    stderr.writeln(
      'Usage: dart run tool/quality/check_code_quality.dart '
      '--metrics <DCL JSON>',
    );
    exitCode = 64;
    return;
  }

  final generatedAdapterViolation = _checkGeneratedDriftAdapter();
  final violations = <String>[
    ?generatedAdapterViolation,
    ...checkFileLengths(),
    ..._checkDartFunctionMetrics(),
    ...checkParameterCounts(),
    ...checkDclMetrics(metricsPath),
  ];

  if (violations.isNotEmpty) {
    stderr.writeln('Code quality violations:');
    for (final violation in violations) {
      stderr.writeln('  - $violation');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Code quality thresholds passed.');
}

List<String> checkParameterCounts() {
  final files = _projectFiles(['*.dart']);
  if (files.error case final error?) return [error];
  return [
    for (final path in files.paths)
      if (!_isDriftAdapter(path))
        ...parameterCountViolations(File(path).readAsStringSync(), path),
  ];
}

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}

List<String> checkFileLengths() {
  final files = _projectFiles(['*.dart', '*.kt', '*.kts', '*.java', '*.sh']);
  if (files.error case final error?) return [error];

  final violations = <String>[];
  for (final path in files.paths) {
    if (_isDriftAdapter(path)) continue;
    final lineCount = File(path).readAsLinesSync().length;
    if (lineCount <= _fileLengthLimit) continue;
    violations.add('$path has $lineCount lines (limit $_fileLengthLimit).');
  }
  return violations;
}

List<String> _checkDartFunctionMetrics() {
  final files = _projectFiles(['*.dart']);
  if (files.error case final error?) return [error];

  final violations = <String>[];
  for (final path in files.paths) {
    if (_isDriftAdapter(path)) continue;
    final parsed = parseFile(
      path: path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    if (parsed.errors.isNotEmpty) {
      violations.add('$path could not be parsed for function metrics.');
      continue;
    }
    violations.addAll(
      dartFunctionMetricViolations(parsed.unit, parsed.lineInfo, path),
    );
  }
  return violations;
}

({Set<String> paths, String? error}) _projectFiles(List<String> patterns) {
  final result = Process.runSync('git', [
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
    '--',
    ...patterns,
  ]);
  if (result.exitCode != 0) {
    return (
      paths: const {},
      error: 'Unable to enumerate project source files: ${result.stderr}',
    );
  }
  final paths = (result.stdout as String)
      .split('\n')
      .where((path) => path.isNotEmpty && File(path).existsSync())
      .toSet();
  return (paths: paths, error: null);
}

List<String> checkDclMetrics(String metricsPath) {
  final decoded =
      jsonDecode(File(metricsPath).readAsStringSync()) as Map<String, dynamic>;
  final records = decoded['records'] as List<dynamic>;
  if (records.isEmpty) return ['DCL reported no source records.'];
  final violations = <String>[];
  for (final recordValue in records) {
    final record = recordValue as Map<String, dynamic>;
    final path = record['path'] as String;
    if (_isDriftAdapter(path)) continue;
    final functions = record['functions'] as Map<String, dynamic>;
    for (final functionEntry in functions.entries) {
      final function = functionEntry.value as Map<String, dynamic>;
      final metrics = function['metrics'] as List<dynamic>;
      violations.addAll(
        _checkFunctionMetrics('$path|${functionEntry.key}', metrics),
      );
    }
  }
  return violations;
}

List<String> _checkFunctionMetrics(String key, List<dynamic> metrics) {
  final violations = <String>[];
  final requiredMetrics = _metricLimits.keys.toSet();
  for (final metricValue in metrics) {
    final metric = metricValue as Map<String, dynamic>;
    final id = metric['metricsId'] as String;
    final limit = _metricLimits[id];
    if (limit == null) continue;
    if (!requiredMetrics.remove(id)) violations.add('$key|$id is duplicated.');
    final value = metric['value'] as num;
    if (!value.isFinite || value < 0) {
      violations.add('$key|$id is invalid.');
    } else if (value > limit) {
      violations.add('$key|$id is $value (limit $limit).');
    }
  }
  for (final id in requiredMetrics) {
    violations.add('$key|$id is missing.');
  }
  return violations;
}

bool _isDriftAdapter(String path) =>
    p.equals(p.absolute(path), p.absolute(_driftAdapter));

String? _checkGeneratedDriftAdapter() {
  if (FileSystemEntity.typeSync(_driftAdapter, followLinks: false) !=
      FileSystemEntityType.file) {
    return 'Expected a regular Drift adapter at $_driftAdapter.';
  }
  final lines = File(_driftAdapter).readAsLinesSync();
  if (lines.length < 3 ||
      lines[0] != _generatedHeader ||
      lines[1].isNotEmpty ||
      lines[2] != _databasePart) {
    return 'Expected the generated header and $_databasePart in $_driftAdapter.';
  }
  return null;
}
