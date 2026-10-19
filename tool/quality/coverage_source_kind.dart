import 'package:analyzer/dart/ast/ast.dart';

/// Classifies units without independently instrumented coverage records.
String? nonInstrumentableSourceReason(CompilationUnit unit) {
  if (unit.directives.any((directive) => directive is PartOfDirective)) {
    return 'part fragment';
  }
  if (unit.declarations.isNotEmpty && unit.declarations.every(_isContract)) {
    return 'abstract interfaces and typedefs only';
  }
  return null;
}

bool _isContract(CompilationUnitMember declaration) {
  if (declaration is GenericTypeAlias || declaration is FunctionTypeAlias) {
    return true;
  }
  if (declaration is! ClassDeclaration || declaration.abstractKeyword == null) {
    return false;
  }
  return declaration.body.members.every(
    (member) => member is MethodDeclaration && !member.isComplete,
  );
}
