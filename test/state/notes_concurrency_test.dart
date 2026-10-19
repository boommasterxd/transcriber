import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/state/notes_controller.dart';
import 'package:transcriber/state/providers.dart';

void main() {
  late Directory root;
  late AppDatabase mainDatabase;
  late AppDatabase shareDatabase;
  late NotesRepository mainRepository;
  late NotesRepository shareRepository;
  late ProviderContainer mainEngine;
  late ProviderContainer shareEngine;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('notes_concurrency_');
    final file = File('${root.path}/notes.sqlite');
    mainDatabase = AppDatabase(NativeDatabase(file));
    mainRepository = NotesRepository(mainDatabase);
    await mainRepository.load();
    shareDatabase = AppDatabase(NativeDatabase(file));
    shareRepository = NotesRepository(shareDatabase);
    mainEngine = _engine(mainRepository);
    shareEngine = _engine(shareRepository);
    mainEngine.read(notesControllerProvider);
    shareEngine.read(notesControllerProvider);
  });

  tearDown(() async {
    mainEngine.dispose();
    shareEngine.dispose();
    await mainDatabase.close();
    await shareDatabase.close();
    await root.delete(recursive: true);
  });

  test(
    'stale main and share engines preserve each other saved notes',
    () async {
      await mainEngine
          .read(notesControllerProvider.notifier)
          .add(_note('main'));
      await shareEngine
          .read(notesControllerProvider.notifier)
          .add(_note('share'));

      expect((await mainRepository.load()).map((note) => note.id).toSet(), {
        'main',
        'share',
      });
      await mainEngine.read(notesControllerProvider.notifier).refresh();
      expect(mainEngine.read(notesControllerProvider), isEmpty);
      expect((await mainRepository.loadHistoryPage()).totalCount, 2);
    },
  );

  test(
    'stale deletes and toggles leave unrelated persisted updates intact',
    () async {
      final main = mainEngine.read(notesControllerProvider.notifier);
      final share = shareEngine.read(notesControllerProvider.notifier);
      await main.add(_note('main'));
      await share.add(_note('share'));
      await main.toggleTodo('share', 0);
      await share.toggleTodo('share', 0);
      await main.delete('main');

      final remaining = (await shareRepository.load()).single;
      expect(remaining.id, 'share');
      expect(remaining.todos.single.done, isFalse);
      expect(remaining.points.single, 'Point share');
      expect(remaining.fullTranscriptText, 'Transcript share');
    },
  );

  test(
    'parallel controller operations publish all committed results',
    () async {
      final controller = mainEngine.read(notesControllerProvider.notifier);
      await Future.wait([
        controller.add(_note('one')),
        controller.add(_note('two')),
      ]);
      await Future.wait([
        controller.toggleTodo('one', 0),
        controller.refresh(),
      ]);

      expect(mainEngine.read(notesControllerProvider), isEmpty);
      expect((await mainRepository.findById('one'))!.todos.single.done, isTrue);
      expect((await mainRepository.load()), hasLength(2));
    },
  );

  test(
    'an add failure rolls back note and child mutations together',
    () => _verifyRollback(mainRepository, shareRepository, mainDatabase),
  );
  test(
    'repeated restoration changes only its own children',
    () => _verifyRestoration(mainRepository, shareRepository),
  );
}

Future<void> _verifyRollback(
  NotesRepository repository,
  NotesRepository peer,
  AppDatabase database,
) async {
  final original = _note('stable');
  await repository.add(original);
  await database.customStatement('''
CREATE TEMP TRIGGER reject_note_points BEFORE INSERT ON note_points
BEGIN SELECT RAISE(ABORT, 'injected write failure'); END
''');

  await expectLater(
    repository.add(_note('other')),
    throwsA(
      predicate<Object>(
        (error) => error.toString().contains('injected write failure'),
      ),
    ),
  );
  final loaded = (await peer.load()).single;
  expect(loaded.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
  expect(
    loaded.toJson()..remove('createdAt'),
    original.toJson()..remove('createdAt'),
  );
}

Future<void> _verifyRestoration(
  NotesRepository repository,
  NotesRepository peer,
) async {
  await repository.add(_note('stable'));
  await peer.add(_note('other'));
  await repository.add(_note('stable'));
  await repository.toggleTodo('stable', -1);
  await repository.toggleTodo('missing', 0);
  await repository.remove('missing');

  final loaded = await repository.load();
  expect(loaded, hasLength(2));
  expect(loaded.every((note) => note.todos.length == 1), isTrue);
  expect(loaded.every((note) => note.points.length == 1), isTrue);
}

ProviderContainer _engine(NotesRepository repository) => ProviderContainer(
  overrides: [
    initialNotesProvider.overrideWithValue(const []),
    notesRepositoryProvider.overrideWithValue(repository),
  ],
);

TranscriptNote _note(String id) => TranscriptNote(
  metadata: NoteMetadata(
    id: id,
    title: id,
    speaker: '',
    source: NoteSource.shared,
    durationSec: 1,
    createdAt: DateTime.utc(2026),
  ),
  origins: const NoteOrigins(
    asrIsLocal: false,
    summaryIsLocal: false,
    asrName: 'test-asr',
    asrSub: 'test',
    llmName: '',
    llmSub: '',
  ),
  content: NoteContent(
    gist: '',
    points: ['Point $id'],
    todos: [TodoItem(text: 'Task $id')],
    transcript: [TranscriptLine(text: 'Transcript $id')],
  ),
);
