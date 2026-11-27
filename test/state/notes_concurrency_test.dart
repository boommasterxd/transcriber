import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/state/history_controller.dart';
import 'package:transcriber/state/note_detail_provider.dart';
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
    'stale deletes and toggles leave unrelated persisted updates intact',
    () async {
      final main = mainEngine.read(notesControllerProvider.notifier);
      final share = shareEngine.read(notesControllerProvider.notifier);
      await main.add(_note('main'));
      await share.add(_note('share'));
      final detailProvider = noteDetailProvider('share');
      final subscription = mainEngine.listen(detailProvider, (_, _) {});
      addTearDown(subscription.close);
      final initial = (await mainEngine.read(detailProvider.future))!;
      final page = await mainEngine.read(historyControllerProvider.future);
      await main.refresh();
      expect(mainEngine.read(detailProvider).value, same(initial));
      expect(
        mainEngine.read(historyControllerProvider).value?.entries,
        same(page.entries),
      );

      await mainEngine.read(detailProvider.notifier).toggleTodo(0);
      final toggled = mainEngine.read(detailProvider).value!;
      expect(toggled.todos.single.done, isTrue);
      expect(toggled.transcript, same(initial.transcript));
      await share.toggleTodo('share', 0);
      await main.refresh();
      final refreshed = await mainEngine.read(detailProvider.future);
      expect(refreshed?.todos.single.done, isFalse);
      expect(
        mainEngine.read(historyControllerProvider).value?.entries,
        same(page.entries),
      );
      await main.delete('main');

      final remaining = (await shareRepository.load()).single;
      expect(remaining.id, 'share');
      expect(remaining.todos.single.done, isFalse);
      expect(remaining.points.single, 'Point share');
      expect(remaining.fullTranscriptText, 'Transcript share');
    },
  );

  test(
    'a failed write rolls back both notes and their children',
    () => _verifyRollback(mainRepository, shareRepository, mainDatabase),
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

  final rejected = throwsA(
    predicate<Object>(
      (error) => error.toString().contains('injected write failure'),
    ),
  );
  await expectLater(repository.add(_note('other')), rejected);
  await expectLater(
    repository.saveAll([for (var i = 0; i < 130; i++) _note('batch-$i')]),
    rejected,
  );
  final loaded = (await peer.load()).single;
  expect(loaded.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
  expect(
    loaded.toJson()..remove('createdAt'),
    original.toJson()..remove('createdAt'),
  );
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
