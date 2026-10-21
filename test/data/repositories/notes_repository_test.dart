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
    _registerSnapshotTests(() => database, () => repository);
    _registerDeletionQueueTests(() => repository);
    _registerSameConnectionRaceTest(() => repository);
    _registerCrossConnectionRaceTest();
  });
}

void _registerSnapshotTests(
  AppDatabase Function() database,
  NotesRepository Function() repository,
) {
  _registerLoadOrderingTest(repository);
  _registerSaveAllReplacementTest(database, repository);
  _registerDuplicateSnapshotTest(repository);
  _registerSummaryErrorTest(repository);
}

void _registerLoadOrderingTest(NotesRepository Function() repository) {
  test('loads notes newest first with ordered child collections', () async {
    await repository().saveAll([
      _note('old', DateTime.utc(2025, 1, 1)),
      _note('new', DateTime.utc(2025, 3, 1)),
    ]);

    final loaded = await repository().load();

    expect(loaded.map((note) => note.id), ['new', 'old']);
    expect(loaded.first.points, ['Point new']);
    expect(loaded.first.todos.single.done, isTrue);
    expect(loaded.first.transcript.single.text, 'Transcript new');
    expect(loaded.first.summaryError, isNull);
  });
}

void _registerSaveAllReplacementTest(
  AppDatabase Function() database,
  NotesRepository Function() repository,
) {
  test('saveAll replaces the complete note snapshot atomically', () async {
    await repository().saveAll([_note('first', DateTime.utc(2025, 1, 1))]);
    await repository().saveAll([_note('second', DateTime.utc(2025, 2, 1))]);

    final loaded = await repository().load();
    expect(loaded.map((note) => note.id), ['second']);
    expect(
      await database().select(database().notePointsTable).get(),
      hasLength(1),
    );
    expect(await database().select(database().notesTable).get(), hasLength(1));
  });
}

void _registerDuplicateSnapshotTest(NotesRepository Function() repository) {
  test('rejects duplicate note ids before changing persisted data', () async {
    await repository().saveAll([_note('stable', DateTime.utc(2025, 1, 1))]);

    await expectLater(
      repository().saveAll([
        _note('duplicate', DateTime.utc(2025, 1, 1)),
        _note('duplicate', DateTime.utc(2025, 2, 1)),
      ]),
      throwsArgumentError,
    );

    expect((await repository().load()).single.id, 'stable');
  });
}

void _registerSummaryErrorTest(NotesRepository Function() repository) {
  test('persists summary errors while retaining transcript data', () async {
    final note = _note(
      'failed-summary',
      DateTime.utc(2025, 1, 1),
    ).copyWith(summaryError: 'Summary failed');
    await repository().saveAll([note]);

    final restored = (await repository().load()).single;

    expect(restored.summaryError, 'Summary failed');
    expect(restored.createdAt.isAtSameMomentAs(note.createdAt), isTrue);
    final restoredFields = restored.toJson()..remove('createdAt');
    final originalFields = note.toJson()..remove('createdAt');
    expect(restoredFields, originalFields);
  });
}

void _registerDeletionQueueTests(NotesRepository Function() repository) {
  _registerRetainedRemovalTest(repository);
  _registerSharedAudioReferenceTest(repository);
  _registerPendingQueryBoundsTest(repository);
}

void _registerRetainedRemovalTest(NotesRepository Function() repository) {
  test('note removal queues retained audio until restore', () async {
    final notes = repository();
    final note = _retainedNote('undo', '/retained/undo.wav');
    await notes.add(note);

    await notes.remove(note.id);

    expect(await notes.pendingAudioDeletionPaths(), [note.audioPath]);
    expect(await notes.findById(note.id), isNull);

    await notes.add(note);

    expect(await notes.pendingAudioDeletionPaths(), isEmpty);
    expect(await notes.findById(note.id), isNotNull);
  });
}

void _registerSharedAudioReferenceTest(NotesRepository Function() repository) {
  test('deleting one note preserves audio referenced by another', () async {
    final notes = repository();
    const audioPath = '/retained/shared.wav';
    await notes.saveAll([
      _retainedNote('first', audioPath),
      _retainedNote('second', audioPath),
    ]);

    await notes.remove('first');

    expect(await notes.pendingAudioDeletionPaths(), [audioPath]);
    expect((await notes.findById('second'))?.audioPath, audioPath);
  });
}

void _registerPendingQueryBoundsTest(NotesRepository Function() repository) {
  test(
    'pending deletion query rejects limits outside its memory bound',
    () async {
      for (final limit in [
        0,
        NotesRepository.maxPendingAudioDeletionBatchSize + 1,
      ]) {
        await expectLater(
          repository().pendingAudioDeletionPaths(limit: limit),
          throwsArgumentError,
        );
      }
    },
  );
}

void _registerSameConnectionRaceTest(NotesRepository Function() repository) {
  test('restore waits for a pending deletion attempt to finish', () async {
    final notes = repository();
    final note = _retainedNote('racing-undo', '/retained/racing-undo.wav');
    await notes.add(note);
    await notes.remove(note.id);
    final deleteStarted = Completer<void>();
    final finishDelete = Completer<bool>();

    final deleting = notes.tryProcessPendingAudioDeletion(note.audioPath!, (_) {
      deleteStarted.complete();
      return finishDelete.future;
    });
    await deleteStarted.future;
    var restored = false;
    final adding = notes.add(note).then((_) => restored = true);

    expect(restored, isFalse);
    finishDelete.complete(false);
    expect(await deleting, isFalse);
    await adding;

    expect(restored, isTrue);
    expect(await notes.findById(note.id), isNotNull);
    expect(await notes.pendingAudioDeletionPaths(), isEmpty);
  });
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
