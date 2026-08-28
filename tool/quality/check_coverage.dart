import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

const _lineThreshold = 85.0;
const _statementThreshold = 85.0;
const _functionThreshold = 85.0;
const _branchThreshold = 80.0;

void main(List<String> arguments) {
  final path = arguments.isEmpty ? 'coverage/lcov.info' : arguments.single;
  final report = CoverageReport.parse(File(path).readAsLinesSync());
  final failures = report.thresholdFailures();
  stdout.writeln(report.summary());
  if (failures.isEmpty) return;
  for (final failure in failures) {
    stderr.writeln(failure);
  }
  exitCode = 1;
}

final class CoverageReport {
  const CoverageReport({
    required this.coveredLines,
    required this.totalLines,
    required this.coveredBranches,
    required this.totalBranches,
    required this.coveredFunctions,
    required this.totalFunctions,
    required this.coveredSources,
    required this.totalSources,
    required this.missingSources,
  });

  final int coveredLines;
  final int totalLines;
  final int coveredBranches;
  final int totalBranches;
  final int coveredFunctions;
  final int totalFunctions;
  final int coveredSources;
  final int totalSources;
  final List<String> missingSources;

  double get lineRate => _percentage(coveredLines, totalLines);
  double get statementRate => lineRate;
  double get branchRate => _percentage(coveredBranches, totalBranches);
  double get functionRate => _percentage(coveredFunctions, totalFunctions);

  factory CoverageReport.parse(List<String> lines) {
    var coveredLines = 0;
    var totalLines = 0;
    var coveredBranches = 0;
    var totalBranches = 0;
    var coveredFunctions = 0;
    var totalFunctions = 0;
    final sources = <_SourceCoverage>[];
    _SourceCoverage? currentSource;

    for (final line in lines) {
      if (line.startsWith('SF:')) {
        currentSource = _SourceCoverage(line.substring(3));
        sources.add(currentSource);
      } else if (line.startsWith('DA:')) {
        totalLines++;
        final fields = line.substring(3).split(',');
        final sourceLine = int.parse(fields[0]);
        final hits = int.parse(fields[1]);
        currentSource?.lineHits[sourceLine] = hits;
        if (hits > 0) coveredLines++;
      } else if (line.startsWith('BRDA:')) {
        totalBranches++;
        final hits = line.substring(5).split(',').last;
        if (hits != '-' && int.parse(hits) > 0) coveredBranches++;
      } else if (line.startsWith('FNDA:')) {
        totalFunctions++;
        final hits = int.parse(line.substring(5).split(',').first);
        if (hits > 0) coveredFunctions++;
      }
    }

    // Flutter currently omits FNDA records. Derive a function proxy from the
    // analyzer AST and line hits so each instrumented declaration or closure is
    // counted, rather than treating an entire source file as one function.
    if (totalFunctions == 0) {
      for (final source in sources) {
        final functionCoverage = source.functionCoverage();
        totalFunctions += functionCoverage.total;
        coveredFunctions += functionCoverage.covered;
      }
    }

    final requiredSources = _trackedProductionSources();
    final reportedSources = sources
        .map((source) => File(source.path).absolute.path)
        .toSet();
    final missingSources =
        requiredSources.entries
            .where((entry) => !reportedSources.contains(entry.key))
            .map((entry) => entry.value)
            .toList()
          ..sort();

    return CoverageReport(
      coveredLines: coveredLines,
      totalLines: totalLines,
      coveredBranches: coveredBranches,
      totalBranches: totalBranches,
      coveredFunctions: coveredFunctions,
      totalFunctions: totalFunctions,
      coveredSources: requiredSources.length - missingSources.length,
      totalSources: requiredSources.length,
      missingSources: missingSources,
    );
  }

  List<String> thresholdFailures() {
    final failures = <String>[];
    if (missingSources.isNotEmpty) {
      final preview = missingSources.take(10).join(', ');
      final remainder = missingSources.length > 10
          ? ' and ${missingSources.length - 10} more'
          : '';
      failures.add(
        'Coverage is missing ${missingSources.length} maintained source files: '
        '$preview$remainder.',
      );
    }
    _check(failures, 'Line', lineRate, _lineThreshold, totalLines);
    _check(
      failures,
      'Statement proxy',
      statementRate,
      _statementThreshold,
      totalLines,
    );
    _check(
      failures,
      'Function proxy',
      functionRate,
      _functionThreshold,
      totalFunctions,
    );
    _check(failures, 'Branch', branchRate, _branchThreshold, totalBranches);
    return failures;
  }

  String summary() =>
      'Coverage: sources $coveredSources/$totalSources, '
      'lines ${lineRate.toStringAsFixed(2)}%, '
      'statements ${statementRate.toStringAsFixed(2)}%, '
      'functions ${functionRate.toStringAsFixed(2)}%, '
      'branches ${branchRate.toStringAsFixed(2)}%.';

  static void _check(
    List<String> failures,
    String name,
    double actual,
    double required,
    int denominator,
  ) {
    if (denominator == 0) {
      failures.add('$name coverage has no instrumented records.');
    } else if (actual < required) {
      failures.add(
        '$name coverage is ${actual.toStringAsFixed(2)}%; required $required%.',
      );
    }
  }

  static double _percentage(int covered, int total) =>
      total == 0 ? 0 : covered * 100 / total;
}

Map<String, String> _trackedProductionSources() {
  final result = Process.runSync('git', [
    'ls-files',
    '--',
    'lib/*.dart',
    'lib/**/*.dart',
  ]);
  if (result.exitCode != 0) {
    throw StateError('Unable to enumerate maintained Dart sources.');
  }
  final paths = (result.stdout as String)
      .split('\n')
      .where((path) => path.isNotEmpty)
      .toSet();
  if (paths.isEmpty) {
    throw StateError('No maintained Dart sources were found.');
  }
  return {for (final path in paths) File(path).absolute.path: path};
}

final class _SourceCoverage {
  _SourceCoverage(this.path);

  final String path;
  final Map<int, int> lineHits = {};

  ({int covered, int total}) functionCoverage() {
    final parsed = parseFile(
      path: path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    if (parsed.errors.isNotEmpty) {
      throw FormatException('Unable to parse $path for function coverage.');
    }
    final collector = _FunctionSpanCollector(parsed.lineInfo);
    parsed.unit.accept(collector);
    var covered = 0;
    var total = 0;
    for (final span in collector.spans) {
      final hits = lineHits.entries
          .where((entry) => entry.key >= span.start && entry.key <= span.end)
          .map((entry) => entry.value)
          .toList();
      if (hits.isEmpty) continue;
      total++;
      if (hits.any((value) => value > 0)) covered++;
    }
    return (covered: covered, total: total);
  }
}

final class _FunctionSpanCollector extends RecursiveAstVisitor<void> {
  _FunctionSpanCollector(this.lineInfo);

  final LineInfo lineInfo;
  final List<({int start, int end})> spans = [];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _add(node);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _add(node);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _add(node);
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is! FunctionDeclaration) _add(node);
    super.visitFunctionExpression(node);
  }

  void _add(AstNode node) {
    spans.add((
      start: lineInfo.getLocation(node.offset).lineNumber,
      end: lineInfo.getLocation(node.end).lineNumber,
    ));
  }
}
