import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/audio_ownership.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';

void main() {
  group('notes repository', () {
    late AppDatabase database;
    late NotesRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = NotesRepository(database);
    });

    tearDown(() => database.close());
    _registerDeletionQueueTests(() => repository);
    _registerCrossConnectionRaceTest();
  });
}

void _registerDeletionQueueTests(NotesRepository Function() repository) {
  _registerRetainedRemovalTest(repository);
}

void _registerRetainedRemovalTest(NotesRepository Function() repository) {
  test(
    'undo restores the deleted version and preserves retained audio',
    () async {
      final notes = repository();
      final note = _retainedNote('undo', '/retained/undo.wav');
      await notes.add(note);

      await notes.toggleTodo(note.id, 0);
      final deleted = await notes.removeForUndo(note.id);

      expect(await notes.pendingAudioDeletionPaths(), [note.audioPath]);
      expect(await notes.findById(note.id), isNull);

      await notes.add(deleted!);

      expect(await notes.pendingAudioDeletionPaths(), isEmpty);
      final restored = await notes.findById(note.id);
      expect(restored?.todos.single.done, isFalse);
      expect(restored?.audioPath, note.audioPath);
    },
  );
}

void _registerCrossConnectionRaceTest() {
  test(
    'another database connection cannot restore during file deletion',
    () async {
      final connections = await _openRepositoryConnections();
      addTearDown(connections.close);
      final note = _retainedNote('cross-engine-undo', '/retained/cross.wav');
      await connections.first.add(note);
      await connections.first.remove(note.id);
      await connections.second.load();
      final deleteStarted = Completer<void>();
      final finishDelete = Completer<bool>();
      final deleting = connections.first.tryProcessPendingAudioDeletion(
        note.audioPath!,
        (_) {
          deleteStarted.complete();
          return finishDelete.future;
        },
      );
      await deleteStarted.future;

      await expectLater(
        connections.second.add(note),
        throwsA(
          predicate<Object>((error) => error.toString().contains('locked')),
        ),
      );
      finishDelete.complete(false);
      expect(await deleting, isFalse);
      await connections.second.add(note);

      expect(await connections.second.findById(note.id), isNotNull);
      expect(await connections.first.pendingAudioDeletionPaths(), isEmpty);
    },
  );
}

Future<_RepositoryConnections> _openRepositoryConnections() async {
  final warning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final root = await Directory.systemTemp.createTemp('audio-delete-race-');
  final file = File('${root.path}/notes.sqlite');
  final firstDatabase = AppDatabase(NativeDatabase(file));
  final secondDatabase = AppDatabase(
    NativeDatabase(
      file,
      setup: (sqlite) => sqlite.execute('PRAGMA busy_timeout = 0'),
    ),
  );
  return _RepositoryConnections(
    root: root,
    firstDatabase: firstDatabase,
    secondDatabase: secondDatabase,
    restoreDatabaseWarning: warning,
  );
}

TranscriptNote _retainedNote(String id, String path) => _note(
  id,
  DateTime.utc(2025, 4, 1),
).copyWith(audioPath: path, audioOwnership: AudioOwnership.retained);

TranscriptNote _note(String id, DateTime createdAt) => TranscriptNote(
  metadata: NoteMetadata(
    id: id,
    title: 'Title $id',
    speaker: 'Speaker $id',
    source: NoteSource.recording,
    durationSec: 42,
    createdAt: createdAt,
  ),
  origins: const NoteOrigins(
    asrIsLocal: true,
    summaryIsLocal: false,
    asrName: 'ASR',
    asrSub: 'Local',
    llmName: 'LLM',
    llmSub: 'Cloud',
  ),
  content: NoteContent(
    gist: 'Gist $id',
    points: ['Point $id'],
    todos: [TodoItem(text: 'Todo $id', done: true)],
    transcript: [TranscriptLine(text: 'Transcript $id')],
  ),
  audioPath: '/external/$id.m4a',
);

final class _RepositoryConnections {
  const _RepositoryConnections({
    required this.root,
    required this.firstDatabase,
    required this.secondDatabase,
    required this.restoreDatabaseWarning,
  });

  final Directory root;
  final AppDatabase firstDatabase;
  final AppDatabase secondDatabase;
  final bool restoreDatabaseWarning;

  NotesRepository get first => NotesRepository(firstDatabase);
  NotesRepository get second => NotesRepository(secondDatabase);

  Future<void> close() async {
    await firstDatabase.close();
    await secondDatabase.close();
    await root.delete(recursive: true);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = restoreDatabaseWarning;
  }
}
