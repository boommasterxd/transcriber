import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/data/models/transcript_note.dart';
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
    fixture.repository.loaded = [existing];
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
    fixture.repository.loaded = [old];
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
    fixture.repository.loaded = [second, first];
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
      fixture.repository.loaded = [note];
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
      fixture.repository.loaded = [note];
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
  late ProviderContainer container;
  late FakeNotesRepository repository;
  bool _containerInitialized = false;

  Future<void> setUp() async {
    SharedPreferences.setMockInitialValues({});
    repository = FakeNotesRepository(await SharedPreferences.getInstance());
    recreateContainer();
  }

  void recreateContainer() {
    if (_containerInitialized) container.dispose();
    container = ProviderContainer(
      overrides: [notesRepositoryProvider.overrideWithValue(repository)],
    );
    _containerInitialized = true;
  }

  void tearDown() {
    container.dispose();
    _containerInitialized = false;
  }
}

TranscriptNote _note(String id, DateTime createdAt, {List<TodoItem>? todos}) =>
    TranscriptNote(
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
      transcript: const [TranscriptLine(time: '00:01', text: 'Text')],
      audioPath: '/recordings/$id.wav',
    );
