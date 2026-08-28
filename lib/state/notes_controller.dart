import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/transcript_note.dart';
import 'providers.dart';

/// In-memory list of processed notes, backed by [NotesRepository].
class NotesController extends Notifier<List<TranscriptNote>> {
  @override
  List<TranscriptNote> build() => ref.read(notesRepositoryProvider).load();

  Future<void> _persist(List<TranscriptNote> next) async {
    state = next;
    await ref.read(notesRepositoryProvider).saveAll(next);
  }

  Future<void> add(TranscriptNote note) => _persist(
    [note, ...state]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  Future<void> delete(String id) =>
      _persist(state.where((n) => n.id != id).toList());

  TranscriptNote? byId(String id) {
    for (final note in state) {
      if (note.id == id) return note;
    }
    return null;
  }

  Future<void> toggleTodo(String noteId, int index) async {
    final next = state.map((note) {
      if (note.id != noteId) return note;
      final todos = note.todos
          .asMap()
          .entries
          .map(
            (e) => e.key == index
                ? TodoItem(text: e.value.text, done: !e.value.done)
                : e.value,
          )
          .toList();
      return note.copyWith(todos: todos);
    }).toList();
    await _persist(next);
  }
}

final notesControllerProvider =
    NotifierProvider<NotesController, List<TranscriptNote>>(
      NotesController.new,
    );
