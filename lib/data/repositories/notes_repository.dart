import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/database_error_boundary.dart';
import '../models/audio_ownership.dart';
import '../models/note_history.dart';
import '../models/transcript_note.dart';
import 'notes_history_query.dart';

/// Persists notes and their ordered child collections in Drift.
class NotesRepository {
  static const maxPendingAudioDeletionBatchSize = 128;
  static const _snapshotBatchSize = 128;

  NotesRepository(this._database);

  final AppDatabase _database;
  late final NotesHistoryQuery _history = NotesHistoryQuery(_database);

  Future<HistoryPage> loadHistoryPage({
    String query = '',
    HistoryCursor? cursor,
    bool previous = false,
    int limit = 50,
  }) => _database.transaction(
    () => _history.load(
      query: query,
      cursor: cursor,
      previous: previous,
      limit: limit,
    ),
  );

  Future<int?> loadHistoryTotal(HistoryPage page) =>
      _database.transaction(() => _history.loadTotal(page));

  /// The history counter and this connection's view of other engines' commits.
  Future<({int history, int peer})> readNotesRevision() async {
    final row = await _database
        .customSelect(
          'SELECT revision, data_version '
          'FROM notes_history_state CROSS JOIN pragma_data_version()',
        )
        .getSingle();
    return (
      history: row.read<int>('revision'),
      peer: row.read<int>('data_version'),
    );
  }

  /// Explicit complete snapshots for imports and test fixtures only.
  Future<List<TranscriptNote>> load() => _database.transaction(_load);

  Future<TranscriptNote?> findById(String id) =>
      _database.transaction(() => _findById(id));

  /// Returns the oldest queued retained audio deletion candidates first.
  Future<List<String>> pendingAudioDeletionPaths({int limit = 128}) async {
    if (limit <= 0 || limit > maxPendingAudioDeletionBatchSize) {
      throw ArgumentError.value(limit, 'limit');
    }
    final query = _database.select(_database.pendingAudioDeletionsTable);
    query
      ..orderBy([(table) => OrderingTerm.asc(table.rowId)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map((row) => row.path).toList(growable: false);
  }

  /// Processes one queued file while serializing note restoration against it.
  Future<bool> tryProcessPendingAudioDeletion(
    String path,
    Future<bool> Function(String path) deleteFile,
  ) => _database.transaction(() async {
    // Claim the marker before checking references. The DELETE takes SQLite's
    // writer lock, including across the share engine's separate connection.
    if (!await _claimPendingAudioDeletion(path)) return true;

    if (await _hasRetainedAudioReference(path)) {
      return true;
    }

    if (!await deleteFile(path)) {
      // Reinsert behind remaining candidates so failures cannot block recovery.
      await _queuePendingAudioDeletion(path);
      return false;
    }
    return true;
  });

  Future<void> _queuePendingAudioDeletion(String path) => _database
      .into(_database.pendingAudioDeletionsTable)
      .insertOnConflictUpdate(
        PendingAudioDeletionsTableCompanion.insert(path: path),
      );

  Future<bool> _claimPendingAudioDeletion(String path) async {
    final removed = await (_database.delete(
      _database.pendingAudioDeletionsTable,
    )..where((table) => table.path.equals(path))).go();
    return removed != 0;
  }

  Future<bool> _hasRetainedAudioReference(String path) async {
    final row =
        await (_database.selectOnly(_database.notesTable)
              ..addColumns([_database.notesTable.id])
              ..where(
                _database.notesTable.audioPath.equals(path) &
                    _database.notesTable.audioOwnership.equals(
                      AudioOwnership.retained.id,
                    ),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<TranscriptNote?> _findById(String id) async {
    final row = await (_database.select(
      _database.notesTable,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final points =
        await (_database.select(_database.notePointsTable)
              ..where((table) => table.noteId.equals(id))
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();
    final todos =
        await (_database.select(_database.noteTodosTable)
              ..where((table) => table.noteId.equals(id))
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();
    final segments =
        await (_database.select(_database.transcriptSegmentsTable)
              ..where((table) => table.noteId.equals(id))
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();
    return _fromRow(
      row,
      points.map((point) => point.content).toList(),
      todos
          .map((todo) => TodoItem(text: todo.content, done: todo.done))
          .toList(),
      segments.map((line) => TranscriptLine(text: line.content)).toList(),
    );
  }

  Future<List<TranscriptNote>> _load() async {
    final rows = await (_database.select(
      _database.notesTable,
    )..orderBy([(table) => OrderingTerm.desc(table.createdAt)])).get();
    if (rows.isEmpty) return const [];

    final noteIds = rows.map((row) => row.id).toSet();
    final points = await (_database.select(
      _database.notePointsTable,
    )..orderBy([(table) => OrderingTerm.asc(table.position)])).get();
    final todos = await (_database.select(
      _database.noteTodosTable,
    )..orderBy([(table) => OrderingTerm.asc(table.position)])).get();
    final segments = await (_database.select(
      _database.transcriptSegmentsTable,
    )..orderBy([(table) => OrderingTerm.asc(table.position)])).get();

    final pointsByNote = _groupPoints(points, noteIds);
    final todosByNote = _groupTodos(todos, noteIds);
    final segmentsByNote = _groupSegments(segments, noteIds);
    return [
      for (final row in rows)
        _fromRow(
          row,
          pointsByNote[row.id] ?? const [],
          todosByNote[row.id] ?? const [],
          segmentsByNote[row.id] ?? const [],
        ),
    ];
  }

  /// Adds or restores one note without replacing another engine's snapshot.
  Future<TranscriptNote> add(TranscriptNote note) =>
      _database.transaction(() async {
        final path = note.audioPath;
        if (note.audioOwnership == AudioOwnership.retained && path != null) {
          await _claimPendingAudioDeletion(path);
        }
        return _storeNote(note);
      });

  /// Tracks the target before moving audio out of disposable staging.
  Future<TranscriptNote> addWithStagedAudio(
    TranscriptNote note,
    Future<void> Function() promoteAudio,
  ) async {
    final path = note.audioPath;
    if (note.audioOwnership != AudioOwnership.retained || path == null) {
      throw ArgumentError('Staged audio requires a retained path.');
    }
    await _queuePendingAudioDeletion(path);
    return _database.transaction(() async {
      // Promotion may only run while the claim transaction owns the writer.
      // On rollback the durable candidate becomes visible to recovery again.
      if (!await _claimPendingAudioDeletion(path)) {
        throw const DatabaseOperationException();
      }
      await promoteAudio();
      return _storeNote(note);
    });
  }

  Future<TranscriptNote> _storeNote(TranscriptNote note) async {
    await _database
        .into(_database.notesTable)
        .insertOnConflictUpdate(_toNoteCompanion(note));
    await _deleteChildren(note.id);
    await _database.batch((batch) {
      batch.insertAll(_database.notePointsTable, _pointRows([note]));
      batch.insertAll(_database.noteTodosTable, _todoRows([note]));
      batch.insertAll(_database.transcriptSegmentsTable, _segmentRows([note]));
    });
    return (await _findById(note.id))!;
  }

  /// Deletes only the requested note and returns its persisted audio metadata.
  Future<NotesDeletion> remove(String id) => _database.transaction(() async {
    final row =
        await (_database.selectOnly(_database.notesTable)
              ..addColumns([
                _database.notesTable.audioPath,
                _database.notesTable.audioOwnership,
              ])
              ..where(_database.notesTable.id.equals(id)))
            .getSingleOrNull();
    final deleted = row == null
        ? null
        : DeletedNoteAudio(
            id: id,
            audioPath: row.read(_database.notesTable.audioPath),
            audioOwnership: AudioOwnership.fromId(
              row.read(_database.notesTable.audioOwnership),
            ),
          );
    if (deleted != null) {
      await _remove(
        id,
        deleted.audioOwnership == AudioOwnership.retained
            ? deleted.audioPath
            : null,
      );
    }
    return NotesDeletion(deleted);
  });

  /// Captures the row and its children in the same transaction that removes it.
  Future<TranscriptNote?> removeForUndo(String id) => _database.transaction(
    () async {
      final note = await _findById(id);
      if (note == null) return null;
      await _remove(
        id,
        note.audioOwnership == AudioOwnership.retained ? note.audioPath : null,
      );
      return note;
    },
  );

  Future<void> _remove(String id, String? retainedAudioPath) async {
    if (retainedAudioPath != null) {
      await _queuePendingAudioDeletion(retainedAudioPath);
    }
    await _deleteChildren(id);
    await (_database.delete(
      _database.notesTable,
    )..where((table) => table.id.equals(id))).go();
  }

  /// Toggles a persisted item atomically without rewriting unrelated data.
  Future<TodoItem?> toggleTodo(String noteId, int index) async {
    final table = _database.noteTodosTable;
    final rows =
        await (_database.update(table)..where(
              (row) => row.noteId.equals(noteId) & row.position.equals(index),
            ))
            .writeReturning(
              NoteTodosTableCompanion.custom(done: table.done.not()),
            );
    if (rows.isEmpty) return null;
    final todo = rows.single;
    return TodoItem(text: todo.content, done: todo.done);
  }

  Future<void> _deleteChildren(String id) async {
    await (_database.delete(
      _database.notePointsTable,
    )..where((table) => table.noteId.equals(id))).go();
    await (_database.delete(
      _database.noteTodosTable,
    )..where((table) => table.noteId.equals(id))).go();
    await (_database.delete(
      _database.transcriptSegmentsTable,
    )..where((table) => table.noteId.equals(id))).go();
  }

  /// Explicit snapshot replacement for imports and test fixtures only.
  Future<void> saveAll(List<TranscriptNote> notes) async {
    final ids = <String>{};
    for (final note in notes) {
      if (!ids.add(note.id)) {
        throw ArgumentError.value(note.id, 'notes', 'Duplicate note id');
      }
    }

    await _database.transaction(() => replaceAllInTransaction(notes));
  }

  /// Replaces the persisted snapshot within the caller's transaction.
  Future<void> replaceAllInTransaction(List<TranscriptNote> notes) async {
    await _database.delete(_database.notePointsTable).go();
    await _database.delete(_database.noteTodosTable).go();
    await _database.delete(_database.transcriptSegmentsTable).go();
    await _database.delete(_database.notesTable).go();
    await _insertSnapshotBatches(
      _database.notesTable,
      notes.map(_toNoteCompanion),
    );
    await _insertSnapshotBatches(_database.notePointsTable, _pointRows(notes));
    await _insertSnapshotBatches(_database.noteTodosTable, _todoRows(notes));
    await _insertSnapshotBatches(
      _database.transcriptSegmentsTable,
      _segmentRows(notes),
    );
  }

  Future<void> _insertSnapshotBatches<T extends Table, D>(
    TableInfo<T, D> table,
    Iterable<Insertable<D>> rows,
  ) async {
    final iterator = rows.iterator;
    while (iterator.moveNext()) {
      final chunk = [iterator.current];
      while (chunk.length < _snapshotBatchSize && iterator.moveNext()) {
        chunk.add(iterator.current);
      }
      await _database.batch((batch) => batch.insertAll(table, chunk));
    }
  }

  TranscriptNote _fromRow(
    NotesTableData row,
    List<String> points,
    List<TodoItem> todos,
    List<TranscriptLine> segments,
  ) => TranscriptNote(
    metadata: NoteMetadata(
      id: row.id,
      title: row.title,
      speaker: row.speaker,
      source: NoteSource.fromId(row.source),
      durationSec: row.durationSec,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    ),
    origins: NoteOrigins(
      asrIsLocal: row.asrIsLocal,
      summaryIsLocal: row.summaryIsLocal,
      asrName: row.asrName,
      asrSub: row.asrSub,
      llmName: row.llmName,
      llmSub: row.llmSub,
    ),
    content: NoteContent(
      gist: row.gist,
      summaryError: row.summaryError,
      points: points,
      todos: todos,
      transcript: segments,
    ),
    audioPath: row.audioPath,
    audioOwnership: AudioOwnership.fromId(row.audioOwnership),
    titleIsAiGenerated: row.titleIsAiGenerated,
  );

  NotesTableCompanion _toNoteCompanion(TranscriptNote note) =>
      NotesTableCompanion.insert(
        id: note.id,
        title: note.title,
        titleSearch: Value(note.title.toLowerCase()),
        speaker: note.speaker,
        source: note.source.id,
        durationSec: note.durationSec,
        createdAt: note.createdAt.millisecondsSinceEpoch,
        asrIsLocal: note.asrIsLocal,
        summaryIsLocal: note.summaryIsLocal,
        asrName: note.asrName,
        asrSub: note.asrSub,
        llmName: note.llmName,
        llmSub: note.llmSub,
        gist: note.gist,
        summaryError: Value(note.summaryError),
        audioPath: Value(note.audioPath),
        audioOwnership: note.audioOwnership.id,
        titleIsAiGenerated: Value(note.titleIsAiGenerated),
      );

  Iterable<NotePointsTableCompanion> _pointRows(List<TranscriptNote> notes) =>
      notes.expand(
        (note) => note.points.indexed.map(
          (point) => NotePointsTableCompanion.insert(
            noteId: note.id,
            position: point.$1,
            content: point.$2,
          ),
        ),
      );

  Iterable<NoteTodosTableCompanion> _todoRows(List<TranscriptNote> notes) =>
      notes.expand(
        (note) => note.todos.indexed.map(
          (todo) => NoteTodosTableCompanion.insert(
            noteId: note.id,
            position: todo.$1,
            content: todo.$2.text,
            done: todo.$2.done,
          ),
        ),
      );

  Iterable<TranscriptSegmentsTableCompanion> _segmentRows(
    List<TranscriptNote> notes,
  ) => notes.expand(
    (note) => note.transcript.indexed.map(
      (line) => TranscriptSegmentsTableCompanion.insert(
        noteId: note.id,
        position: line.$1,
        content: line.$2.text,
      ),
    ),
  );

  Map<String, List<String>> _groupPoints(
    List<NotePointsTableData> rows,
    Set<String> noteIds,
  ) {
    final result = <String, List<String>>{};
    for (final row in rows) {
      if (noteIds.contains(row.noteId)) {
        result.putIfAbsent(row.noteId, () => []).add(row.content);
      }
    }
    return result;
  }

  Map<String, List<TodoItem>> _groupTodos(
    List<NoteTodosTableData> rows,
    Set<String> noteIds,
  ) {
    final result = <String, List<TodoItem>>{};
    for (final row in rows) {
      if (noteIds.contains(row.noteId)) {
        result
            .putIfAbsent(row.noteId, () => [])
            .add(TodoItem(text: row.content, done: row.done));
      }
    }
    return result;
  }

  Map<String, List<TranscriptLine>> _groupSegments(
    List<TranscriptSegmentsTableData> rows,
    Set<String> noteIds,
  ) {
    final result = <String, List<TranscriptLine>>{};
    for (final row in rows) {
      if (noteIds.contains(row.noteId)) {
        result
            .putIfAbsent(row.noteId, () => [])
            .add(TranscriptLine(text: row.content));
      }
    }
    return result;
  }
}

final class NotesDeletion {
  const NotesDeletion(this.deleted);

  final DeletedNoteAudio? deleted;
}

final class DeletedNoteAudio {
  const DeletedNoteAudio({
    required this.id,
    required this.audioPath,
    required this.audioOwnership,
  });

  final String id;
  final String? audioPath;
  final AudioOwnership audioOwnership;
}
