import 'package:drift/drift.dart';

final class DatabaseOperationException implements Exception {
  const DatabaseOperationException();

  @override
  String toString() => 'The database operation failed.';
}

/// Keeps raw driver errors and their bound values inside the data layer.
final class DatabaseErrorBoundary extends QueryInterceptor {
  Future<T> _protect<T>(Future<T> Function() execute) async {
    try {
      return await execute();
    } catch (_) {
      throw const DatabaseOperationException();
    }
  }

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) =>
      _protect(() => executor.ensureOpen(user));

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) => _protect(() => executor.runBatched(statements));

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _protect(() => executor.runCustom(statement, args));

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _protect(() => executor.runDelete(statement, args));

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _protect(() => executor.runInsert(statement, args));

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _protect(() => executor.runSelect(statement, args));

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _protect(() => executor.runUpdate(statement, args));

  @override
  Future<void> commitTransaction(TransactionExecutor inner) =>
      _protect(inner.send);

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) =>
      _protect(inner.rollback);

  @override
  Future<void> close(QueryExecutor inner) => _protect(inner.close);
}
