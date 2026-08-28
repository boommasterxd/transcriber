import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/audio_ownership.dart';
import '../models/transcript_note.dart';

/// Persists notes and their ordered child collections in Drift.
class NotesRepository {
  NotesRepository(this._database);

  final AppDatabase _database;

  Future<List<TranscriptNote>> load() async {
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
    id: row.id,
    title: row.title,
    speaker: row.speaker,
    source: NoteSource.fromId(row.source),
    durationSec: row.durationSec,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    asrIsLocal: row.asrIsLocal,
    summaryIsLocal: row.summaryIsLocal,
    asrName: row.asrName,
    asrSub: row.asrSub,
    llmName: row.llmName,
    llmSub: row.llmSub,
    gist: row.gist,
    points: points,
    todos: todos,
    transcript: segments,
    audioPath: row.audioPath,
    audioOwnership: AudioOwnership.fromId(row.audioOwnership),
  );

  NotesTableCompanion _toNoteCompanion(TranscriptNote note) =>
      NotesTableCompanion.insert(
        id: note.id,
        title: note.title,
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
        audioPath: note.audioPath == null
            ? const Value.absent()
            : Value(note.audioPath),
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
