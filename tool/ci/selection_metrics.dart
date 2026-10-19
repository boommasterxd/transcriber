import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../quality/coverage_source_kind.dart';
import 'selection_git.dart';

// A restricted scope must support the existing nonempty function and branch
// denominators. Empty test-only scopes are reported separately by coverage.
Future<bool> supportsScopedMetrics(
  SelectionGit git,
  String revision,
  List<String> sources,
) async {
  if (sources.isEmpty) return true;
  var hasFunction = false;
  var hasBranch = false;
  for (final source in sources) {
    final parsed = parseString(
      content: await git.read(['show', '$revision:$source']),
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    if (parsed.errors.isNotEmpty) return false;
    if (nonInstrumentableSourceReason(parsed.unit) != null) continue;
    final pending = <AstNode>[parsed.unit];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      hasFunction = hasFunction || _isFunction(node);
      hasBranch = hasBranch || _isBranch(node);
      if (hasFunction && hasBranch) return true;
      pending.addAll(node.childEntities.whereType<AstNode>());
    }
  }
  return false;
}

bool _isFunction(AstNode node) =>
    node is FunctionDeclaration ||
    node is MethodDeclaration ||
    node is ConstructorDeclaration ||
    node is FunctionExpression;

bool _isBranch(AstNode node) =>
    node is IfStatement ||
    node is SwitchStatement ||
    node is SwitchExpression ||
    node is ForStatement ||
    node is WhileStatement ||
    node is DoStatement ||
    node is CatchClause ||
    node is ConditionalExpression ||
    (node is BinaryExpression &&
        (node.operator.lexeme == '&&' || node.operator.lexeme == '||'));
