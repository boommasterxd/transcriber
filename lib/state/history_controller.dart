import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/note_history.dart';
import '../data/repositories/notes_repository.dart';
import 'providers.dart';

typedef _PagePosition = ({HistoryCursor? cursor, bool previous});
const _firstPage = (cursor: null, previous: false);

/// Retains one metadata page and loads its exact total after publishing it.
class HistoryController extends AsyncNotifier<HistoryPage> {
  String _query = '';
  int _generation = 0;
  int? _loadedRevision;
  _PagePosition _position = _firstPage;
  HistoryPage? _counting;

  String get query => _query;

  HistoryPage? pageForQuery(AsyncValue<HistoryPage> value) {
    final page = value.value;
    return page?.filter == _query.toLowerCase() ? page : null;
  }

  @override
  Future<HistoryPage> build() {
    final repository = ref.read(notesRepositoryProvider);
    listenSelf((_, next) {
      _ensureTotal(repository, next);
    });
    return _loadPage(repository, _position, ++_generation);
  }

  void search(String query) {
    final changed = query.toLowerCase() != _query.toLowerCase();
    _query = query;
    if (!changed) return;
    _position = _firstPage;
    _loadedRevision = null;
    retry();
  }

  void refreshIfChanged(int revision) {
    if (_loadedRevision == revision) {
      _ensureTotal(ref.read(notesRepositoryProvider), state);
    } else {
      retry();
    }
  }

  void retry() {
    _generation++;
    ref.invalidateSelf();
  }

  Future<void> next() => _move(previous: false);
  Future<void> previous() => _move(previous: true);

  Future<void> _move({required bool previous}) async {
    final page = state.asData?.value;
    if (state.isLoading || page == null || page.entries.isEmpty) return;
    if (previous ? !page.hasPrevious : !page.hasNext) return;
    final entry = previous ? page.entries.first : page.entries.last;
    final position = (
      cursor: HistoryCursor.fromEntry(entry),
      previous: previous,
    );
    final generation = ++_generation;
    final repository = ref.read(notesRepositoryProvider);
    final scope = ref;
    state = const AsyncLoading<HistoryPage>();
    final result = await AsyncValue.guard(
      () => _loadPage(repository, position, generation),
    );
    if (scope.mounted && generation == _generation) state = result;
  }

  Future<HistoryPage> _loadPage(
    NotesRepository repository,
    _PagePosition position,
    int generation,
  ) async {
    final scope = ref;
    final query = _query;
    var page = await repository.loadHistoryPage(
      query: query,
      cursor: position.cursor,
      previous: position.previous,
    );
    if (!scope.mounted || generation != _generation) return page;
    var loadedPosition = position;
    if (page.entries.isEmpty && position.cursor != null) {
      page = await repository.loadHistoryPage(query: query);
      loadedPosition = _firstPage;
    }
    if (scope.mounted && generation == _generation) {
      _position = loadedPosition;
      _loadedRevision = page.revision;
    }
    return page;
  }

  void _ensureTotal(NotesRepository repository, AsyncValue<HistoryPage> value) {
    final page = value.asData?.value;
    if (value.isLoading ||
        page == null ||
        page.totalCount != null ||
        identical(_counting, page)) {
      return;
    }
    _counting = page;
    unawaited(_loadTotal(repository, page, _generation));
  }

  Future<void> _loadTotal(
    NotesRepository repository,
    HistoryPage page,
    int generation,
  ) async {
    final scope = ref;
    int? count;
    try {
      count = await repository.loadHistoryTotal(page);
    } catch (_) {
      // A failed count leaves the page and its navigation usable.
      return;
    } finally {
      if (identical(_counting, page)) _counting = null;
    }
    if (count == null || !scope.mounted) return;
    final current = state;
    if (scope.mounted &&
        generation == _generation &&
        !current.isLoading &&
        identical(current.value, page)) {
      state = AsyncData(page.withTotal(count));
    }
  }
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, HistoryPage>(
      HistoryController.new,
      retry: (_, _) => null,
    );
