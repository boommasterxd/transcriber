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
  _HistoryFilter? _lastFilter;

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
    final filter = await _prepareFilter(query.toLowerCase());
    final clauses = [...filter.clauses];
    final variables = [...filter.variables];
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
          'n.asr_sub, n.llm_name, n.llm_sub, n.title_is_ai_generated, '
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
      filter: filter.text,
      revision: filter.revision,
      totalCount: filter.total,
    );
  }

  Future<_HistoryFilter> _prepareFilter(
    String text, {
    QueryRow? snapshot,
  }) async {
    final current = snapshot ?? await _readSnapshot();
    final revision = current.read<int>('revision');
    final previous = _lastFilter;
    if (previous != null &&
        previous.text == text &&
        previous.revision == revision) {
      return previous;
    }
    final phrase = _indexPhrase(text, current.read<bool>('title_index'));
    final useIndex = await _shouldSearchIndex(phrase);
    final (clauses, variables) = _titleFilter(text, useIndex ? phrase : null);
    return _lastFilter = _HistoryFilter(text, revision, clauses, variables);
  }

  Future<QueryRow> _readSnapshot() => database
      .customSelect('SELECT revision, title_index FROM notes_history_state')
      .getSingle();

  Future<int?> loadTotal(HistoryPage page) async {
    final snapshot = await _readSnapshot();
    if (snapshot.read<int>('revision') != page.revision) return null;
    final filter = await _prepareFilter(page.filter, snapshot: snapshot);
    final cached = filter.total;
    if (cached != null) return cached;
    final row = await database
        .customSelect(
          'SELECT COUNT(*) AS total FROM notes n ${_where(filter.clauses)}',
          variables: filter.variables,
        )
        .getSingle();
    return filter.total = row.read<int>('total');
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
    final overflow = await database
        .customSelect(
          '$_titleMatches LIMIT 1 OFFSET ?',
          variables: [Variable(phrase), const Variable(_indexedCandidateLimit)],
        )
        .getSingleOrNull();
    return overflow == null;
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
    titleIsAiGenerated: row.readNullable<bool>('title_is_ai_generated'),
  );
}

final class _HistoryFilter {
  _HistoryFilter(this.text, this.revision, this.clauses, this.variables);

  final String text;
  final int revision;
  final List<String> clauses;
  final List<Variable> variables;
  int? total;
}
