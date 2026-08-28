import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/audio_ownership.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:transcriber/state/notes_controller.dart';
import 'package:transcriber/state/providers.dart';

import 'state_test_fakes.dart';

void main() {
  final fixture = _NotesFixture();
  setUp(fixture.setUp);
  tearDown(fixture.tearDown);
  _registerReadTests(fixture);
  _registerMutationTests(fixture);
  _registerTodoTests(fixture);
  _registerErrorTests(fixture);
}

void _registerReadTests(_NotesFixture fixture) {
  test('loads the repository snapshot and finds notes by id', () {
    final existing = _note('existing', DateTime.utc(2025, 1, 1));
    fixture.initialNotes = [existing];
    fixture.recreateContainer();
    final controller = fixture.container.read(notesControllerProvider.notifier);

    expect(fixture.container.read(notesControllerProvider), [existing]);
    expect(controller.byId('existing'), same(existing));
    expect(controller.byId('missing'), isNull);
  });
}

void _registerMutationTests(_NotesFixture fixture) {
  test('adds notes newest first and persists the complete snapshot', () async {
    final old = _note('old', DateTime.utc(2025, 1, 1));
    final newest = _note('newest', DateTime.utc(2025, 3, 1));
    fixture.initialNotes = [old];
    fixture.recreateContainer();
    final controller = fixture.container.read(notesControllerProvider.notifier);

    await controller.add(newest);

    expect(fixture.container.read(notesControllerProvider).map((n) => n.id), [
      'newest',
      'old',
    ]);
    expect(fixture.repository.saved.single.map((n) => n.id), ['newest', 'old']);
  });

  test('deletes matching notes and leaves unrelated notes intact', () async {
    final first = _note('first', DateTime.utc(2025, 1, 1));
    final second = _note('second', DateTime.utc(2025, 2, 1));
    fixture.initialNotes = [second, first];
    fixture.recreateContainer();
    final controller = fixture.container.read(notesControllerProvider.notifier);

    await controller.delete('first');
    expect(fixture.container.read(notesControllerProvider).map((n) => n.id), [
      'second',
    ]);
    await controller.delete('missing');
    expect(fixture.container.read(notesControllerProvider).map((n) => n.id), [
      'second',
    ]);
    expect(fixture.repository.saved, hasLength(2));
  });

  test('deletes retained note audio from app-managed storage', () async {
    final retainedDirectory = await fixture.storagePaths.retainedAudioDir();
    final audio = File('${retainedDirectory.path}/note.wav');
    await audio.writeAsBytes([1, 2, 3]);
    fixture.initialNotes = [
      _note(
        'retained',
        DateTime.utc(2025),
        audioPath: audio.path,
        audioOwnership: AudioOwnership.retained,
      ),
    ];
    fixture.recreateContainer();

    await fixture.container
        .read(notesControllerProvider.notifier)
        .delete('retained');

    expect(await audio.exists(), isFalse);
  });

  test('preserves external audio when deleting its note', () async {
    final audio = File('${fixture.root.path}/external.wav');
    await audio.writeAsBytes([1]);
    fixture.initialNotes = [
      _note('external', DateTime.utc(2025), audioPath: audio.path),
    ];
    fixture.recreateContainer();

    await fixture.container
        .read(notesControllerProvider.notifier)
        .delete('external');

    expect(await audio.exists(), isTrue);
  });

  test('preserves retained audio when note persistence fails', () async {
    final retainedDirectory = await fixture.storagePaths.retainedAudioDir();
    final audio = File('${retainedDirectory.path}/stable.wav');
    await audio.writeAsBytes([1]);
    fixture.initialNotes = [
      _note(
        'stable',
        DateTime.utc(2025),
        audioPath: audio.path,
        audioOwnership: AudioOwnership.retained,
      ),
    ];
    fixture.repository.failOnSave = true;
    fixture.recreateContainer();

    await expectLater(
      fixture.container.read(notesControllerProvider.notifier).delete('stable'),
      throwsStateError,
    );

    expect(await audio.exists(), isTrue);
  });
}

void _registerTodoTests(_NotesFixture fixture) {
  test(
    'toggles only the selected todo and persists the updated note',
    () async {
      final note = _note(
        'todos',
        DateTime.utc(2025, 1, 1),
        todos: [
          TodoItem(text: 'first'),
          TodoItem(text: 'second', done: true),
        ],
      );
      fixture.initialNotes = [note];
      fixture.recreateContainer();
      final controller = fixture.container.read(
        notesControllerProvider.notifier,
      );

      await controller.toggleTodo('todos', 0);

      final updated = fixture.container.read(notesControllerProvider).single;
      expect(updated.todos.map((todo) => todo.done), [true, true]);
      expect(updated.todos[0].text, 'first');
      expect(fixture.repository.saved.single.single.todos[0].done, isTrue);
    },
  );

  test(
    'ignores an out-of-range todo index without changing note content',
    () async {
      final note = _note(
        'todos',
        DateTime.utc(2025, 1, 1),
        todos: [TodoItem(text: 'only')],
      );
      fixture.initialNotes = [note];
      fixture.recreateContainer();
      final controller = fixture.container.read(
        notesControllerProvider.notifier,
      );

      await controller.toggleTodo('todos', 4);

      expect(
        fixture.container
            .read(notesControllerProvider)
            .single
            .todos
            .single
            .done,
        isFalse,
      );
      expect(fixture.repository.saved.single.single.todos.single.done, isFalse);
    },
  );
}

void _registerErrorTests(_NotesFixture fixture) {
  test(
    'exposes persistence errors while retaining the updated state',
    () async {
      fixture.repository.failOnSave = true;
      final controller = fixture.container.read(
        notesControllerProvider.notifier,
      );
      final note = _note('failed-save', DateTime.utc(2025, 1, 1));

      await expectLater(controller.add(note), throwsStateError);

      expect(fixture.container.read(notesControllerProvider), [note]);
    },
  );
}

class _NotesFixture {
  late AppDatabase database;
  late Directory root;
  late StoragePaths storagePaths;
  late AudioCacheManager cacheManager;
  late ProviderContainer container;
  late FakeNotesRepository repository;
  List<TranscriptNote> initialNotes = [];
  bool _containerInitialized = false;

  Future<void> setUp() async {
    database = createTestDatabase();
    repository = FakeNotesRepository(database);
    root = await Directory.systemTemp.createTemp('notes_controller_test_');
    storagePaths = StoragePaths(
      supportRoot: Directory('${root.path}/support'),
      cacheRoot: Directory('${root.path}/cache'),
    );
    cacheManager = AudioCacheManager(paths: Future.value(storagePaths));
    initialNotes = [];
    recreateContainer();
  }

  void recreateContainer() {
    if (_containerInitialized) container.dispose();
    container = ProviderContainer(
      overrides: [
        initialNotesProvider.overrideWithValue(initialNotes),
        notesRepositoryProvider.overrideWithValue(repository),
        audioCacheManagerProvider.overrideWithValue(cacheManager),
      ],
    );
    _containerInitialized = true;
  }

  Future<void> tearDown() async {
    container.dispose();
    _containerInitialized = false;
    await database.close();
    await root.delete(recursive: true);
  }
}

TranscriptNote _note(
  String id,
  DateTime createdAt, {
  List<TodoItem>? todos,
  String? audioPath,
  AudioOwnership audioOwnership = AudioOwnership.external,
}) => TranscriptNote(
  id: id,
  title: 'Title $id',
  speaker: 'Speaker',
  source: NoteSource.recording,
  durationSec: 10,
  createdAt: createdAt,
  asrIsLocal: true,
  summaryIsLocal: true,
  asrName: 'ASR',
  asrSub: 'Local',
  llmName: 'LLM',
  llmSub: 'Local',
  gist: 'Gist',
  points: const ['Point'],
  todos: todos ?? [TodoItem(text: 'Action')],
  transcript: const [TranscriptLine(text: 'Text')],
  audioPath: audioPath ?? '/recordings/$id.wav',
  audioOwnership: audioOwnership,
);
