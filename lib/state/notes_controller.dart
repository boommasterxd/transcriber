import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/audio_ownership.dart';
import '../data/models/transcript_note.dart';
import 'providers.dart';

/// In-memory list of processed notes, backed by [NotesRepository].
class NotesController extends Notifier<List<TranscriptNote>> {
  @override
  List<TranscriptNote> build() => List.of(ref.watch(initialNotesProvider));

  /// Replaces the in-memory snapshot with the current persisted notes.
  Future<void> refresh() async {
    final persisted = await ref.read(notesRepositoryProvider).load();
    state = persisted;
  }

  Future<void> _persist(List<TranscriptNote> next) async {
    state = next;
    await ref.read(notesRepositoryProvider).saveAll(next);
  }

  Future<void> add(TranscriptNote note) => _persist(
    [note, ...state]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  Future<void> delete(String id, {bool deleteAudio = true}) async {
    final note = byId(id);
    await _persist(state.where((candidate) => candidate.id != id).toList());
    if (deleteAudio && note != null) await deleteNoteAudio(note);
  }

  Future<void> deleteNoteAudio(TranscriptNote note) async {
    if (note.audioOwnership != AudioOwnership.retained) return;
    await ref
        .read(audioCacheManagerProvider)
        .deleteRetainedPath(note.audioPath);
  }

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
