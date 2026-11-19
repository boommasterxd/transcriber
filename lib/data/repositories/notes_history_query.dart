import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/note_history.dart';
import '../models/transcript_note.dart';

/// Reads bounded metadata pages; child rows are counted only for page entries.
final class NotesHistoryQuery {
  NotesHistoryQuery(this.database);

  // Keep index-backed sorts bounded. For common terms the history index can
  // usually provide the first full page directly in chronological order.
  static const _indexedCandidateLimit = 512;
  static const _titleMatches =
      'SELECT rowid FROM notes_title_search WHERE notes_title_search MATCH ?';

  final AppDatabase database;
  ({String filter, int revision, int total, bool useIndex})? _knownCount;

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
    final (count, clauses, variables) = await _prepareFilter(
      query.toLowerCase(),
    );
    if (cursor != null) {
      final comparison = previous ? '>' : '<';
      clauses.add('(n.created_at, n.id) $comparison (?, ?)');
      variables.addAll([
        Variable(cursor.createdAt.millisecondsSinceEpoch),
        Variable(cursor.id),
      ]);
    }
    final where = _where(clauses);
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
      totalCount: count,
    );
  }

  Future<(int, List<String>, List<Variable>)> _prepareFilter(
    String filter,
  ) async {
    final snapshot = await database
        .customSelect('SELECT revision, title_index FROM notes_history_state')
        .getSingle();
    final revision = snapshot.read<int>('revision');
    final cached = _cachedCount(filter, revision);
    final phrase = _indexPhrase(filter, snapshot.read<int>('title_index') == 1);
    final useIndex = cached?.useIndex ?? await _shouldSearchIndex(phrase);
    final (clauses, variables) = _titleFilter(filter, useIndex ? phrase : null);
    final count = cached?.total ?? await _readTotal(clauses, variables);
    _knownCount = (
      filter: filter,
      revision: revision,
      total: count,
      useIndex: useIndex,
    );
    return (count, clauses, variables);
  }

  ({String filter, int revision, int total, bool useIndex})? _cachedCount(
    String filter,
    int revision,
  ) {
    final cached = _knownCount;
    return cached?.filter == filter && cached?.revision == revision
        ? cached
        : null;
  }

  Future<int> _readTotal(List<String> clauses, List<Variable> variables) async {
    final row = await database
        .customSelect(
          'SELECT COUNT(*) AS total FROM notes n ${_where(clauses)}',
          variables: variables,
        )
        .getSingle();
    return row.read<int>('total');
  }

  String? _indexPhrase(String filter, bool indexed) {
    final supported =
        indexed &&
        filter.runes.take(3).length == 3 &&
        !filter.contains('\u0000');
    return supported ? '"${filter.replaceAll('"', '""')}"' : null;
  }

  Future<bool> _shouldSearchIndex(String? phrase) async {
    if (phrase == null) return false;
    final row = await database
        .customSelect(
          'SELECT COUNT(*) AS candidates FROM ($_titleMatches LIMIT ?)',
          variables: [
            Variable(phrase),
            const Variable(_indexedCandidateLimit + 1),
          ],
        )
        .getSingle();
    return row.read<int>('candidates') <= _indexedCandidateLimit;
  }

  (List<String>, List<Variable>) _titleFilter(String filter, String? phrase) {
    if (filter.isEmpty) return ([], []);
    final escaped = filter.replaceAllMapped(
      RegExp(r'[\\%_]'),
      (match) => '\\${match[0]}',
    );
    const literal = "n.title_search LIKE ? ESCAPE '\\'";
    if (phrase == null) return ([literal], [Variable('%$escaped%')]);
    return (
      ['n.rowid IN ($_titleMatches)', literal],
      [Variable(phrase), Variable('%$escaped%')],
    );
  }

  String _where(List<String> clauses) =>
      clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';

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
