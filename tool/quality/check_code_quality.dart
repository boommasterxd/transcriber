import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'parameter_count.dart';
import 'coverage_source_kind.dart';

const _fileLengthLimit = 500;
const _cognitiveComplexityLimit = 25;
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

  final violations = <String>[
    ...checkFileLengths(),
    ...checkCognitiveComplexity(),
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
      if (!_isGeneratedDart(path))
        ...parameterCountViolations(File(path).readAsStringSync(), path),
  ];
}

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}

List<String> checkFileLengths() {
  final files = _projectFiles(['*.dart', '*.kt', '*.kts', '*.sh']);
  if (files.error case final error?) return [error];

  final violations = <String>[];
  for (final path in files.paths) {
    if (_isGeneratedDart(path)) continue;
    final lineCount = File(path).readAsLinesSync().length;
    if (lineCount <= _fileLengthLimit) continue;
    violations.add('$path has $lineCount lines (limit $_fileLengthLimit).');
  }
  return violations;
}

List<String> checkCognitiveComplexity() {
  final files = _projectFiles(['*.dart']);
  if (files.error case final error?) return [error];

  final violations = <String>[];
  for (final path in files.paths) {
    if (_isGeneratedDart(path)) continue;
    final parsed = parseFile(
      path: path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    if (parsed.errors.isNotEmpty) {
      violations.add('$path could not be parsed for cognitive complexity.');
      continue;
    }
    final collector = _FunctionCollector(path, parsed.lineInfo);
    parsed.unit.accept(collector);
    for (final measurement in collector.measurements) {
      if (measurement.value <= _cognitiveComplexityLimit) continue;
      violations.add(
        '${measurement.key} has cognitive complexity ${measurement.value} '
        '(limit $_cognitiveComplexityLimit).',
      );
    }
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
    if (_isGeneratedDart(path)) continue;
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

bool _isGeneratedDart(String path) {
  if (!path.endsWith('.g.dart')) return false;
  final file = File(path);
  if (!file.existsSync()) return false;
  return isGeneratedDartSource(path, file.readAsStringSync());
}

final class CognitiveMeasurement {
  const CognitiveMeasurement(this.key, this.value);

  final String key;
  final int value;
}

final class _FunctionCollector extends RecursiveAstVisitor<void> {
  _FunctionCollector(this.path, this.lineInfo);

  final String path;
  final LineInfo lineInfo;
  final List<CognitiveMeasurement> measurements = [];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _measure(node.name.lexeme, node.functionExpression.body);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _measure(node.name.lexeme, node.body);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final name = node.name?.lexeme ?? 'new';
    _measure(name, node.body);
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is! FunctionDeclaration) {
      final line = lineInfo.getLocation(node.offset).lineNumber;
      _measure('<closure@$line>', node.body);
    }
    super.visitFunctionExpression(node);
  }

  void _measure(String name, FunctionBody body) {
    final visitor = _CognitiveVisitor();
    body.accept(visitor);
    final line = lineInfo.getLocation(body.offset).lineNumber;
    measurements.add(CognitiveMeasurement('$path|$name@$line', visitor.score));
  }
}

final class _CognitiveVisitor extends RecursiveAstVisitor<void> {
  int score = 0;
  int _nesting = 0;

  @override
  void visitIfStatement(IfStatement node) => _nested(node);

  @override
  void visitForStatement(ForStatement node) => _nested(node);

  @override
  void visitWhileStatement(WhileStatement node) => _nested(node);

  @override
  void visitDoStatement(DoStatement node) => _nested(node);

  @override
  void visitSwitchStatement(SwitchStatement node) => _nested(node);

  @override
  void visitCatchClause(CatchClause node) => _nested(node);

  @override
  void visitConditionalExpression(ConditionalExpression node) => _nested(node);

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final operator = node.operator.lexeme;
    if (operator == '&&' || operator == '||') score++;
    super.visitBinaryExpression(node);
  }

  @override
  void visitBreakStatement(BreakStatement node) {
    if (node.label != null) score++;
    super.visitBreakStatement(node);
  }

  @override
  void visitContinueStatement(ContinueStatement node) {
    if (node.label != null) score++;
    super.visitContinueStatement(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  void _nested(AstNode node) {
    score += 1 + _nesting;
    _nesting++;
    node.visitChildren(this);
    _nesting--;
  }
}
