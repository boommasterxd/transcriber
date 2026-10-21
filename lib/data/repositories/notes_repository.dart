import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/audio_ownership.dart';
import '../models/note_history.dart';
import '../models/transcript_note.dart';
import 'notes_history_query.dart';

/// Persists notes and their ordered child collections in Drift.
class NotesRepository {
  static const maxPendingAudioDeletionBatchSize = 128;

  NotesRepository(this._database);

  final AppDatabase _database;

  Future<HistoryPage> loadHistoryPage({
    String query = '',
    HistoryCursor? cursor,
    bool previous = false,
    int limit = 50,
  }) => _database.transaction(
    () => NotesHistoryQuery(
      _database,
    ).load(query: query, cursor: cursor, previous: previous, limit: limit),
  );

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
    final claimed = await (_database.delete(
      _database.pendingAudioDeletionsTable,
    )..where((table) => table.path.equals(path))).go();
    if (claimed == 0) return true;

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
        await _database
            .into(_database.notesTable)
            .insertOnConflictUpdate(_toNoteCompanion(note));
        if (note.audioOwnership == AudioOwnership.retained &&
            note.audioPath != null) {
          await (_database.delete(
            _database.pendingAudioDeletionsTable,
          )..where((table) => table.path.equals(note.audioPath!))).go();
        }
        await _deleteChildren(note.id);
        await _database.batch((batch) {
          batch.insertAll(_database.notePointsTable, _pointRows([note]));
          batch.insertAll(_database.noteTodosTable, _todoRows([note]));
          batch.insertAll(
            _database.transcriptSegmentsTable,
            _segmentRows([note]),
          );
        });
        return (await _findById(note.id))!;
      });

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
    final audioPath = deleted?.audioPath;
    if (deleted?.audioOwnership == AudioOwnership.retained &&
        audioPath != null) {
      await _database
          .into(_database.pendingAudioDeletionsTable)
          .insertOnConflictUpdate(
            PendingAudioDeletionsTableCompanion.insert(path: audioPath),
          );
    }
    await _deleteChildren(id);
    await (_database.delete(
      _database.notesTable,
    )..where((table) => table.id.equals(id))).go();
    return NotesDeletion(deleted);
  });

  /// Toggles a persisted item atomically without rewriting unrelated data.
  Future<TranscriptNote?> toggleTodo(String noteId, int index) =>
      _database.transaction(() async {
        final query = _database.select(_database.noteTodosTable)
          ..where(
            (table) =>
                table.noteId.equals(noteId) & table.position.equals(index),
          );
        final todo = await query.getSingleOrNull();
        if (todo != null) {
          await (_database.update(_database.noteTodosTable)..where(
                (table) =>
                    table.noteId.equals(noteId) & table.position.equals(index),
              ))
              .write(NoteTodosTableCompanion(done: Value(!todo.done)));
        }
        return _findById(noteId);
      });

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
    await _database.batch((batch) {
      batch.insertAll(
        _database.notesTable,
        notes.map(_toNoteCompanion).toList(),
      );
      batch.insertAll(_database.notePointsTable, _pointRows(notes));
      batch.insertAll(_database.noteTodosTable, _todoRows(notes));
      batch.insertAll(_database.transcriptSegmentsTable, _segmentRows(notes));
    });
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
      );

  Iterable<NotePointsTableCompanion> _pointRows(List<TranscriptNote> notes) => [
    for (final note in notes)
      for (var index = 0; index < note.points.length; index++)
        NotePointsTableCompanion.insert(
          noteId: note.id,
          position: index,
          content: note.points[index],
        ),
  ];

  Iterable<NoteTodosTableCompanion> _todoRows(List<TranscriptNote> notes) => [
    for (final note in notes)
      for (var index = 0; index < note.todos.length; index++)
        NoteTodosTableCompanion.insert(
          noteId: note.id,
          position: index,
          content: note.todos[index].text,
          done: note.todos[index].done,
        ),
  ];

  Iterable<TranscriptSegmentsTableCompanion> _segmentRows(
    List<TranscriptNote> notes,
  ) => [
    for (final note in notes)
      for (var index = 0; index < note.transcript.length; index++)
        TranscriptSegmentsTableCompanion.insert(
          noteId: note.id,
          position: index,
          content: note.transcript[index].text,
        ),
  ];

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
