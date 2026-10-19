part of 'check_coverage.dart';

final class _SourceAnalysis {
  const _SourceAnalysis({
    required this.functionSpans,
    required this.branchSpans,
  }) : nonInstrumentableReason = null;

  const _SourceAnalysis.nonInstrumentable(this.nonInstrumentableReason)
    : functionSpans = const [],
      branchSpans = const [];

  final List<_LineSpan> functionSpans, branchSpans;
  final String? nonInstrumentableReason;

  factory _SourceAnalysis.parse(String path) {
    final parsed = parseFile(
      path: path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    if (parsed.errors.isNotEmpty) {
      throw FormatException('Unable to analyze maintained source $path.');
    }
    if (nonInstrumentableSourceReason(parsed.unit) case final reason?) {
      return _SourceAnalysis.nonInstrumentable(reason);
    }
    final functions = _FunctionSpanCollector(parsed.lineInfo);
    final branches = _BranchSpanCollector(parsed.lineInfo);
    parsed.unit.accept(functions);
    parsed.unit.accept(branches);
    return _SourceAnalysis(
      functionSpans: functions.spans,
      branchSpans: branches.spans,
    );
  }
}

final class _FunctionSpanCollector extends RecursiveAstVisitor<void> {
  _FunctionSpanCollector(this.lineInfo);

  final LineInfo lineInfo;
  final List<_LineSpan> spans = [];

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

  void _add(AstNode node) => spans.add(_LineSpan.fromNode(node, lineInfo));
}

final class _BranchSpanCollector extends RecursiveAstVisitor<void> {
  _BranchSpanCollector(this.lineInfo);

  final LineInfo lineInfo;
  final List<_LineSpan> spans = [];

  @override
  void visitIfStatement(IfStatement node) {
    _add(node.thenStatement);
    if (node.elseStatement case final otherwise?) _add(otherwise);
    super.visitIfStatement(node);
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    for (final member in node.members) {
      if (member.statements.isNotEmpty) {
        _addRange(member.statements.first, member.statements.last);
      }
    }
    super.visitSwitchStatement(node);
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    for (final branch in node.cases) {
      _add(branch.expression);
    }
    super.visitSwitchExpression(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    _add(node.body);
    super.visitForStatement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _add(node.body);
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    _add(node.body);
    super.visitDoStatement(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    _add(node.body);
    super.visitCatchClause(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    _add(node.thenExpression);
    _add(node.elseExpression);
    super.visitConditionalExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.operator.lexeme == '&&' || node.operator.lexeme == '||') {
      _add(node.leftOperand);
      _add(node.rightOperand);
    }
    super.visitBinaryExpression(node);
  }

  void _add(AstNode node) => spans.add(_LineSpan.fromNode(node, lineInfo));

  void _addRange(AstNode first, AstNode last) => spans.add(
    _LineSpan(
      lineInfo.getLocation(first.offset).lineNumber,
      lineInfo.getLocation(last.end).lineNumber,
    ),
  );
}

final class _LineSpan {
  const _LineSpan(this.start, this.end);

  factory _LineSpan.fromNode(AstNode node, LineInfo lines) => _LineSpan(
    lines.getLocation(node.offset).lineNumber,
    lines.getLocation(node.end).lineNumber,
  );

  final int start, end;

  bool contains(int line) => line >= start && line <= end;
}
