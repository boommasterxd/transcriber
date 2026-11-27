import 'dart:math';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

const _lineLimit = 100;
const _cyclomaticLimit = 20;
const _cognitiveLimit = 25;
const _nestingLimit = 4;

List<String> dartFunctionMetricViolations(
  CompilationUnit unit,
  LineInfo lineInfo,
  String path,
) {
  final collector = _FunctionCollector(path, lineInfo);
  unit.accept(collector);
  return collector.violations;
}

final class _FunctionCollector extends RecursiveAstVisitor<void> {
  _FunctionCollector(this.path, this.lineInfo);

  final String path;
  final LineInfo lineInfo;
  final List<String> violations = [];

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
    _measure(node.name?.lexeme ?? 'new', node.body);
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is! FunctionDeclaration) {
      _measure('<closure>', node.body, closure: node);
    }
    super.visitFunctionExpression(node);
  }

  void _measure(String name, FunctionBody body, {FunctionExpression? closure}) {
    final metrics = _FunctionMetricsVisitor();
    body.accept(metrics);
    final location = lineInfo.getLocation((closure ?? body).offset);
    final line = location.lineNumber;
    final point = closure == null ? '$line' : '$line:${location.columnNumber}';
    final key = '$path|$name@$point';
    _record(key, 'cognitive complexity', metrics.cognitive, _cognitiveLimit);
    _record(key, 'cyclomatic complexity', metrics.cyclomatic, _cyclomaticLimit);
    if (closure != null) {
      final endLine = lineInfo.getLocation(closure.endToken.offset).lineNumber;
      _record(key, 'lines of code', endLine - line + 1, _lineLimit);
      _record(key, 'maximum nesting level', metrics.blockDepth, _nestingLimit);
    }
  }

  void _record(String key, String metric, int value, int limit) {
    if (value > limit) {
      violations.add('$key has $metric $value (limit $limit).');
    }
  }
}

final class _FunctionMetricsVisitor extends UnifyingAstVisitor<void> {
  // Match the operators that contribute to DCL's cyclomatic metric.
  static const _branchOperators = {
    TokenType.AMPERSAND_AMPERSAND,
    TokenType.BAR_BAR,
    TokenType.QUESTION_PERIOD,
    TokenType.QUESTION_QUESTION,
    TokenType.QUESTION_QUESTION_EQ,
  };

  int cyclomatic = 1;
  int cognitive = 0;
  int blockDepth = 0;
  int _cognitiveNesting = 0;
  int _blockNesting = 0;

  @override
  void visitNode(AstNode node) {
    final nested = _isCognitiveDecision(node);
    if (_isCyclomaticDecision(node, nested)) cyclomatic++;
    for (final token in node.childEntities.whereType<Token>()) {
      if (_branchOperators.contains(token.type)) cyclomatic++;
    }
    if (nested) {
      cognitive += 1 + _cognitiveNesting;
      _cognitiveNesting++;
    }
    super.visitNode(node);
    if (nested) _cognitiveNesting--;
  }

  @override
  void visitBlock(Block node) {
    _blockNesting++;
    blockDepth = max(blockDepth, _blockNesting);
    super.visitBlock(node);
    _blockNesting--;
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final operator = node.operator.type;
    if (operator == TokenType.AMPERSAND_AMPERSAND ||
        operator == TokenType.BAR_BAR) {
      cognitive++;
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitBreakStatement(BreakStatement node) {
    if (node.label != null) cognitive++;
    super.visitBreakStatement(node);
  }

  @override
  void visitContinueStatement(ContinueStatement node) {
    if (node.label != null) cognitive++;
    super.visitContinueStatement(node);
  }

  // The collector measures each of these functions in its own scope.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {}

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  bool _isCognitiveDecision(AstNode node) =>
      node is IfStatement ||
      node is IfElement ||
      node is ForStatement ||
      node is ForElement ||
      node is WhileStatement ||
      node is DoStatement ||
      node is SwitchStatement ||
      node is SwitchExpression ||
      node is CatchClause ||
      node is ConditionalExpression;

  bool _isCyclomaticDecision(AstNode node, bool nested) => switch (node) {
    SwitchStatement() || SwitchExpression() => false,
    SwitchMember() ||
    SwitchExpressionCase() ||
    AssertStatement() ||
    YieldStatement() => true,
    _ => nested,
  };
}
