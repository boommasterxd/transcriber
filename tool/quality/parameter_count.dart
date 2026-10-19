import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

const parameterCountLimit = 6;

typedef ParameterMeasurement = ({String key, int value});

List<ParameterMeasurement> measureParameters(String content, String path) {
  final parsed = parseString(
    content: content,
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  if (parsed.errors.isNotEmpty) {
    throw FormatException('$path could not be parsed for parameter counts.');
  }
  final visitor = _ParameterVisitor(path, parsed.lineInfo);
  parsed.unit.accept(visitor);
  return visitor.measurements;
}

List<String> parameterCountViolations(String content, String path) => [
  for (final measurement in measureParameters(content, path))
    if (measurement.value > parameterCountLimit)
      '${measurement.key} has ${measurement.value} parameters '
          '(limit $parameterCountLimit).',
];

final class _ParameterVisitor extends RecursiveAstVisitor<void> {
  _ParameterVisitor(this.path, this.lineInfo);

  final String path;
  final LineInfo lineInfo;
  final List<ParameterMeasurement> measurements = [];

  @override
  void visitFormalParameterList(FormalParameterList node) {
    final location = lineInfo.getLocation(node.offset);
    measurements.add((
      key:
          '$path|${_name(node.parent)}@'
          '${location.lineNumber}:${location.columnNumber}',
      value: node.parameters.length,
    ));
    super.visitFormalParameterList(node);
  }

  String _name(AstNode? node) => switch (node) {
    ConstructorDeclaration() => 'constructor ${node.name?.lexeme ?? 'new'}',
    MethodDeclaration() => node.name.lexeme,
    FunctionExpression(parent: FunctionDeclaration(:final name)) => name.lexeme,
    FunctionExpression() => '<closure>',
    FunctionTypedFormalParameterSuffix() => '<callback>',
    GenericFunctionType() => '<function type>',
    _ => '<parameters>',
  };
}
