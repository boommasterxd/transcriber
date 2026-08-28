import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

part 'coverage_lcov.dart';
part 'coverage_report.dart';
part 'coverage_source.dart';

const _lineThreshold = 85.0;
const _statementThreshold = 85.0;
const _functionThreshold = 85.0;
const _branchThreshold = 80.0;

void main(List<String> arguments) {
  final path = arguments.isEmpty ? 'coverage/lcov.info' : arguments.single;
  final report = CoverageReport.parse(File(path).readAsLinesSync());
  final failures = report.thresholdFailures();
  stdout.writeln(report.summary());
  for (final failure in failures) {
    stderr.writeln(failure);
  }
  if (failures.isNotEmpty) exitCode = 1;
}
