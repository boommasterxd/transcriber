import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/note_history.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/state/history_controller.dart';
import 'package:transcriber/state/note_detail_provider.dart';
import 'package:transcriber/state/notes_controller.dart';
import 'package:transcriber/state/providers.dart';

import '../ui/screens/home/home_test_helpers.dart';
import 'state_test_fakes.dart';

void main() {
  _registerPagingTest();
  _registerResumeTest();
  _registerFailureTest();
  _registerRaceTest();
  _registerConcurrentDeletionTest();
}

void _registerPagingTest() {
  test(
    'pages replace metadata and search includes notes beyond the first page',
    () async {
      final fixture = await _fixture();
      final container = fixture.container;
      final controller = container.read(historyControllerProvider.notifier);
      final first = await container.read(historyControllerProvider.future);
      expect(first.entries, hasLength(50));
      expect(first.totalCount, 120);
      expect(first.hasPrevious, isFalse);
      await controller.previous();
      await controller.next();
      final second = container.read(historyControllerProvider).requireValue;
      expect(second.entries, hasLength(50));
      expect(second.entries.first.id, isNot(first.entries.first.id));
      await controller.previous();
      expect(
        container.read(historyControllerProvider).requireValue.entries.first.id,
        first.entries.first.id,
      );
      controller.search('Note 0');
      final searched = await container.read(historyControllerProvider.future);
      expect(searched.entries.single.title, 'Note 0');
      controller.search('Note 0');
      expect(
        container.read(historyControllerProvider).requireValue,
        same(searched),
      );
      await controller.next();
      expect(
        container.read(historyControllerProvider).requireValue,
        same(searched),
      );
    },
  );
}

void _registerResumeTest() {
  test(
    'resume invalidation resets pages and reloads selected details',
    () async {
      final fixture = await _fixture();
      final container = fixture.container;
      final repo = container.read(notesRepositoryProvider);
      final detail = container.listen(noteDetailProvider('0'), (_, _) {});
      addTearDown(detail.close);
      expect(
        (await container.read(noteDetailProvider('0').future))?.title,
        'Note 0',
      );
      await container.read(historyControllerProvider.future);
      await container.read(historyControllerProvider.notifier).next();
      await repo.add(
        buildTestNote(
          id: 'external',
          title: 'External',
          createdAt: DateTime(2030),
        ),
      );
      await repo.remove('0');
      await container.read(notesControllerProvider.notifier).refresh();
      final page = await container.read(historyControllerProvider.future);
      expect(page.hasPrevious, isFalse);
      expect(page.entries.first.id, 'external');
      expect(await container.read(noteDetailProvider('0').future), isNull);
    },
  );
}

void _registerFailureTest() {
  test('page errors can be retried and empty pages cannot move', () async {
    final (container: container, repository: repository) = _queuedFixture();
    final first = container.read(historyControllerProvider.future);
    repository.requests.single.completeError(StateError('synthetic failure'));
    await expectLater(first, throwsStateError);
    final controller = container.read(historyControllerProvider.notifier);
    await controller.next();
    controller.retry();
    final retry = container.read(historyControllerProvider.future);
    repository.requests.last.complete(_emptyPage);
    expect((await retry).entries, isEmpty);
    await controller.next();
    await controller.previous();
    expect(repository.requests, hasLength(2));
  });
}

void _registerRaceTest() {
  test(
    'late page results cannot overwrite a new search or concurrent movement',
    () async {
      final (container: container, repository: repository) = _queuedFixture();
      final first = container.read(historyControllerProvider.future);
      final entry = NoteHistoryEntry.fromNote(
        buildTestNote(id: 'a', title: 'A', createdAt: DateTime(2026)),
      );
      repository.requests.single.complete(
        HistoryPage(
          entries: [entry],
          hasNext: true,
          hasPrevious: false,
          totalCount: 2,
        ),
      );
      await first;
      final controller = container.read(historyControllerProvider.notifier);
      final pending = controller.next();
      await controller.next();
      expect(repository.requests, hasLength(2));
      controller.search('new');
      final search = container.read(historyControllerProvider.future);
      repository.requests.last.complete(_emptyPage);
      await search;
      repository.requests[1].complete(
        HistoryPage(
          entries: [entry],
          hasNext: false,
          hasPrevious: true,
          totalCount: 2,
        ),
      );
      await pending;
      expect(
        container.read(historyControllerProvider).requireValue.entries,
        isEmpty,
      );
    },
  );
}

void _registerConcurrentDeletionTest() {
  test('an emptied deep page resets to the first page', () async {
    final fixture = await _fixture();
    final container = fixture.container;
    final first = await container.read(historyControllerProvider.future);
    final repository = container.read(notesRepositoryProvider);
    final retained = await repository.findById(first.entries.first.id);
    await repository.saveAll([retained!]);
    await container.read(historyControllerProvider.notifier).next();
    final result = container.read(historyControllerProvider).requireValue;
    expect(result.entries.single.id, retained.id);
    expect(result.hasPrevious, isFalse);
  });
}

({ProviderContainer container, _QueuedHistoryRepository repository})
_queuedFixture() {
  final database = createTestDatabase();
  addTearDown(database.close);
  final repository = _QueuedHistoryRepository(database);
  final container = _container(repository);
  addTearDown(container.dispose);
  return (container: container, repository: repository);
}

const _emptyPage = HistoryPage(
  entries: [],
  hasNext: false,
  hasPrevious: false,
  totalCount: 0,
);

Future<({ProviderContainer container})> _fixture() async {
  final database = createTestDatabase();
  addTearDown(database.close);
  final repository = NotesRepository(database);
  await repository.saveAll(
    List.generate(
      120,
      (index) => buildTestNote(
        id: '$index',
        title: 'Note $index',
        createdAt: DateTime.fromMillisecondsSinceEpoch(index * 1000),
      ),
    ),
  );
  final container = _container(repository);
  addTearDown(container.dispose);
  return (container: container);
}

ProviderContainer _container(NotesRepository repository) => ProviderContainer(
  overrides: [
    initialNotesProvider.overrideWithValue(const []),
    notesRepositoryProvider.overrideWithValue(repository),
  ],
);

class _QueuedHistoryRepository extends NotesRepository {
  _QueuedHistoryRepository(super.database);
  final requests = <Completer<HistoryPage>>[];

  @override
  Future<HistoryPage> loadHistoryPage({
    String query = '',
    HistoryCursor? cursor,
    bool previous = false,
    int limit = 50,
  }) {
    final result = Completer<HistoryPage>();
    requests.add(result);
    return result.future;
  }
}
