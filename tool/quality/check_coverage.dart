import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../ci/test_selection.dart';

part 'coverage_lcov.dart';
part 'coverage_report.dart';
part 'coverage_scope.dart';
part 'coverage_source.dart';

const _lineThreshold = 85.0;
const _statementThreshold = 85.0;
const _functionThreshold = 85.0;
const _branchThreshold = 80.0;

Future<void> main(List<String> arguments) async {
  try {
    final options = CoverageOptions.parse(arguments);
    final scope = await CoverageScope.load(options.scopePlan);
    final report = CoverageReport.parse(
      File(options.lcovPath).readAsLinesSync(),
      sources: scope.sources,
      isPartial: scope.isPartial,
    );
    final failures = report.thresholdFailures();
    stdout.writeln(report.summary());
    for (final failure in failures) {
      stderr.writeln(failure);
    }
    if (failures.isNotEmpty) exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('Coverage check failed: $error');
    exitCode = 1;
  }
}
