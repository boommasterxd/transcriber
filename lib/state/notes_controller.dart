import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/audio_ownership.dart';
import '../data/models/transcript_note.dart';
import 'providers.dart';

/// Bounded cache of recently changed details, backed by [NotesRepository].
class NotesController extends Notifier<List<TranscriptNote>> {
  Future<void> _pending = Future.value();

  @override
  List<TranscriptNote> build() =>
      ref.watch(initialNotesProvider).take(8).toList();

  /// Invalidates detail and history consumers after another engine writes.
  Future<void> refresh() => _enqueue(() async => _publish(<TranscriptNote>[]));

  Future<void> add(TranscriptNote note) => _enqueue(
    () async => _cache(await ref.read(notesRepositoryProvider).add(note)),
  );

  Future<void> delete(String id, {bool deleteAudio = true}) =>
      _enqueue(() async {
        final result = await ref.read(notesRepositoryProvider).remove(id);
        _evict(id);
        final note = result.deleted;
        if (deleteAudio &&
            note?.audioOwnership == AudioOwnership.retained &&
            ref.mounted) {
          await ref
              .read(audioCacheManagerProvider)
              .deleteRetainedPath(note!.audioPath);
        }
      });

  void _publish(List<TranscriptNote> notes) {
    if (ref.mounted) state = notes;
  }

  void _cache(TranscriptNote note) {
    if (!ref.mounted) return;
    _publish([note, ...state.where((cached) => cached.id != note.id).take(7)]);
  }

  void _evict(String id) {
    if (ref.mounted) _publish(state.where((note) => note.id != id).toList());
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _pending.then((_) => operation());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
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

  Future<void> toggleTodo(String noteId, int index) => _enqueue(() async {
    final note = await ref
        .read(notesRepositoryProvider)
        .toggleTodo(noteId, index);
    if (note == null) {
      _evict(noteId);
    } else {
      _cache(note);
    }
  });
}

final notesControllerProvider =
    NotifierProvider<NotesController, List<TranscriptNote>>(
      NotesController.new,
    );
