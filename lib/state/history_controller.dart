import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/note_history.dart';
import 'notes_controller.dart';
import 'providers.dart';

/// Retains one metadata page; search and cross-engine refresh reset its cursor.
class HistoryController extends AsyncNotifier<HistoryPage> {
  String _query = '';
  int _generation = 0;
  String get query => _query;

  @override
  Future<HistoryPage> build() {
    ref.watch(notesControllerProvider);
    _generation++;
    return ref.read(notesRepositoryProvider).loadHistoryPage(query: _query);
  }

  void search(String query) {
    if (query == _query) return;
    _query = query;
    _generation++;
    ref.invalidateSelf();
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
    final generation = ++_generation;
    final query = _query;
    final repository = ref.read(notesRepositoryProvider);
    state = const AsyncLoading<HistoryPage>();
    final result = await AsyncValue.guard(() async {
      final next = await repository.loadHistoryPage(
        query: query,
        cursor: HistoryCursor(createdAt: entry.createdAt, id: entry.id),
        previous: previous,
      );
      if (next.entries.isEmpty && ref.mounted && generation == _generation) {
        return repository.loadHistoryPage(query: query);
      }
      return next;
    });
    if (ref.mounted && generation == _generation) state = result;
  }
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, HistoryPage>(
      HistoryController.new,
      retry: (_, _) => null,
    );
