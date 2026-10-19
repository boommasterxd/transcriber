import 'package:analyzer/dart/ast/ast.dart';

bool isGeneratedDartSource(String path, String content) =>
    path.endsWith('.g.dart') &&
    content.startsWith('// GENERATED CODE - DO NOT MODIFY BY HAND');

/// Classifies units without independently instrumented coverage records.
String? nonInstrumentableSourceReason(CompilationUnit unit) {
  if (unit.declarations.isEmpty && unit.directives.isNotEmpty) {
    return 'library directives only';
  }
  if (unit.declarations.isNotEmpty && unit.declarations.every(_isContract)) {
    return 'abstract interfaces and typedefs only';
  }
  if (unit.declarations.isNotEmpty &&
      unit.declarations.every(_isConstantDeclaration)) {
    return 'constant data and memberless enums only';
  }
  return null;
}

bool _isConstantDeclaration(CompilationUnitMember declaration) =>
    switch (declaration) {
      EnumDeclaration() => declaration.body.members.isEmpty,
      TopLevelVariableDeclaration() => declaration.variables.isConst,
      _ => false,
    };

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
