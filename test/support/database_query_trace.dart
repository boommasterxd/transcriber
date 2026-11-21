import 'package:drift/drift.dart';

/// Observes executed statements at the database boundary, including transactions.
final class DatabaseQueryTrace extends QueryInterceptor {
  final selects = <(String, List<Object?>)>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects.add((statement, args));
    return executor.runSelect(statement, args);
  }
}
