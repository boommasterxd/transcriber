import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/note_history.dart';
import '../models/transcript_note.dart';

/// Reads bounded metadata pages; child rows are counted only for page entries.
final class NotesHistoryQuery {
  const NotesHistoryQuery(this.database);

  final AppDatabase database;

  Future<HistoryPage> load({
    String query = '',
    HistoryCursor? cursor,
    bool previous = false,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 50) {
      throw RangeError.range(limit, 1, 50, 'limit');
    }
    if (previous && cursor == null) {
      throw ArgumentError('Previous pages require a cursor');
    }
    final filter = query.toLowerCase();
    final variables = <Variable>[];
    final clauses = <String>[];
    if (filter.isNotEmpty) {
      clauses.add("n.title_search LIKE ? ESCAPE '\\'");
      final escaped = filter.replaceAllMapped(
        RegExp(r'[\\%_]'),
        (match) => '\\${match[0]}',
      );
      variables.add(Variable('%$escaped%'));
    }
    final filterClause = clauses.isEmpty
        ? ''
        : 'WHERE ${clauses.join(' AND ')}';
    final count = await database
        .customSelect(
          'SELECT COUNT(*) AS total FROM notes n $filterClause',
          variables: List.of(variables),
        )
        .getSingle();
    if (cursor != null) {
      final comparison = previous ? '>' : '<';
      clauses.add('(n.created_at, n.id) $comparison (?, ?)');
      variables.addAll([
        Variable(cursor.createdAt.millisecondsSinceEpoch),
        Variable(cursor.id),
      ]);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final direction = previous ? 'ASC' : 'DESC';
    final rows = await database
        .customSelect(
          'SELECT n.id, n.title, n.speaker, n.source, n.duration_sec, '
          'n.created_at, n.asr_is_local, n.summary_is_local, n.asr_name, '
          'n.asr_sub, n.llm_name, n.llm_sub, '
          '(SELECT COUNT(*) FROM note_todos t WHERE t.note_id = n.id) AS todo_count '
          'FROM notes n $where ORDER BY n.created_at $direction, n.id $direction '
          'LIMIT ?',
          variables: [...variables, Variable(limit + 1)],
        )
        .get();
    final hasMore = rows.length > limit;
    final entries = rows.take(limit).map(_entry).toList();
    return HistoryPage(
      entries: List.unmodifiable(previous ? entries.reversed : entries),
      hasNext: previous ? cursor != null : hasMore,
      hasPrevious: previous ? hasMore : cursor != null,
      totalCount: count.read<int>('total'),
    );
  }

  NoteHistoryEntry _entry(QueryRow row) => NoteHistoryEntry(
    metadata: NoteMetadata(
      id: row.read<String>('id'),
      title: row.read<String>('title'),
      speaker: row.read<String>('speaker'),
      source: NoteSource.fromId(row.read<String>('source')),
      durationSec: row.read<int>('duration_sec'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
      ),
    ),
    origins: NoteOrigins(
      asrIsLocal: row.read<bool>('asr_is_local'),
      summaryIsLocal: row.read<bool>('summary_is_local'),
      asrName: row.read<String>('asr_name'),
      asrSub: row.read<String>('asr_sub'),
      llmName: row.read<String>('llm_name'),
      llmSub: row.read<String>('llm_sub'),
    ),
    todoCount: row.read<int>('todo_count'),
  );
}
