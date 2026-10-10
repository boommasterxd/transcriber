import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';

void main() {
  late AppDatabase database;
  late NotesRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = NotesRepository(database);
  });

  tearDown(() => database.close());

  test('loads notes newest first with ordered child collections', () async {
    await repository.saveAll([
      _note('old', DateTime.utc(2025, 1, 1)),
      _note('new', DateTime.utc(2025, 3, 1)),
    ]);

    final loaded = await repository.load();

    expect(loaded.map((note) => note.id), ['new', 'old']);
    expect(loaded.first.points, ['Point new']);
    expect(loaded.first.todos.single.done, isTrue);
    expect(loaded.first.transcript.single.text, 'Transcript new');
    expect(loaded.first.summaryError, isNull);
  });

  test('saveAll replaces the complete note snapshot atomically', () async {
    await repository.saveAll([_note('first', DateTime.utc(2025, 1, 1))]);
    await repository.saveAll([_note('second', DateTime.utc(2025, 2, 1))]);

    final loaded = await repository.load();
    expect(loaded.map((note) => note.id), ['second']);
    expect(await database.select(database.notePointsTable).get(), hasLength(1));
    expect(await database.select(database.notesTable).get(), hasLength(1));
  });

  test('rejects duplicate note ids before changing persisted data', () async {
    await repository.saveAll([_note('stable', DateTime.utc(2025, 1, 1))]);

    await expectLater(
      repository.saveAll([
        _note('duplicate', DateTime.utc(2025, 1, 1)),
        _note('duplicate', DateTime.utc(2025, 2, 1)),
      ]),
      throwsArgumentError,
    );

    expect((await repository.load()).single.id, 'stable');
  });

  test('persists summary errors while retaining transcript data', () async {
    final note = _note(
      'failed-summary',
      DateTime.utc(2025, 1, 1),
    ).copyWith(summaryError: 'Summary failed');
    await repository.saveAll([note]);

    final restored = (await NotesRepository(database).load()).single;

    expect(restored.summaryError, 'Summary failed');
    expect(restored.createdAt.isAtSameMomentAs(note.createdAt), isTrue);
    final restoredFields = restored.toJson()..remove('createdAt');
    final originalFields = note.toJson()..remove('createdAt');
    expect(restoredFields, originalFields);
  });
}

TranscriptNote _note(String id, DateTime createdAt) => TranscriptNote(
  id: id,
  title: 'Title $id',
  speaker: 'Speaker $id',
  source: NoteSource.recording,
  durationSec: 42,
  createdAt: createdAt,
  asrIsLocal: true,
  summaryIsLocal: false,
  asrName: 'ASR',
  asrSub: 'Local',
  llmName: 'LLM',
  llmSub: 'Cloud',
  gist: 'Gist $id',
  points: ['Point $id'],
  todos: [TodoItem(text: 'Todo $id', done: true)],
  transcript: [TranscriptLine(text: 'Transcript $id')],
  audioPath: '/external/$id.m4a',
);
