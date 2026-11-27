import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/audio_ownership.dart';
import '../data/models/transcript_note.dart';
import 'history_controller.dart';
import 'providers.dart';

/// Bounded cache of recently changed details, backed by [NotesRepository].
class NotesController extends Notifier<List<TranscriptNote>> {
  Future<void> _pending = Future.value();
  Future<int>? _peerRevision;
  final _undoableNotes = <String, TranscriptNote>{};

  @override
  List<TranscriptNote> build() =>
      ref.watch(initialNotesProvider).take(8).toList();

  /// Checks for changes made while this engine was paused.
  Future<void> refresh() => _enqueue(() async {
    final previous = _peerRevision;
    final revision = await ref
        .read(notesRepositoryProvider)
        .readNotesRevision();
    final peerChanged = previous == null || await previous != revision.peer;
    if (!ref.mounted) return;
    _peerRevision = Future.value(revision.peer);
    if (peerChanged) {
      _publish(const []);
      ref.invalidate(notesPeerRevisionProvider);
    }
    if (ref.read(historyControllerProvider.exists)) {
      ref
          .read(historyControllerProvider.notifier)
          .refreshIfChanged(revision.history);
    }
  });

  Future<void> trackPeerRevision() async {
    final pending = _peerRevision ??= _readPeerRevision();
    try {
      await pending;
    } catch (_) {
      if (identical(_peerRevision, pending)) _peerRevision = null;
      rethrow;
    }
  }

  Future<int> _readPeerRevision() async =>
      (await ref.read(notesRepositoryProvider).readNotesRevision()).peer;

  Future<void> add(TranscriptNote note) => _enqueue(() async {
    _cache(await ref.read(notesRepositoryProvider).add(note));
    _invalidateHistory();
  });

  Future<void> addWithStagedAudio(
    TranscriptNote note,
    Future<void> Function() promoteAudio,
  ) => _enqueue(() async {
    final saved = await ref
        .read(notesRepositoryProvider)
        .addWithStagedAudio(note, promoteAudio);
    _cache(saved);
    _invalidateHistory();
  });

  Future<void> delete(String id, {bool deleteAudio = true}) =>
      _enqueue(() async {
        final result = await ref.read(notesRepositoryProvider).remove(id);
        _evict(id);
        final note = result.deleted;
        if (note != null) _invalidateHistory();
        if (deleteAudio && note?.audioOwnership == AudioOwnership.retained) {
          await _finalizeAudio(note?.audioPath);
        }
      });

  Future<TranscriptNote?> deleteForUndo(String id) => _enqueue(() async {
    final deleted = await ref.read(notesRepositoryProvider).removeForUndo(id);
    _evict(id);
    if (deleted != null) {
      _undoableNotes[id] = deleted;
      _invalidateHistory();
    }
    return deleted;
  });

  Future<void> restoreDeletedNote(TranscriptNote note) => _enqueue(() async {
    if (!identical(_undoableNotes[note.id], note)) return;
    final saved = await ref.read(notesRepositoryProvider).add(note);
    _undoableNotes.remove(note.id);
    _cache(saved);
    _invalidateHistory();
  });

  Future<void> finalizeDeletion(TranscriptNote note) => _enqueue(() async {
    if (!identical(_undoableNotes[note.id], note)) return;
    _undoableNotes.remove(note.id);
    await _finalizeAudio(_retainedPath(note));
  });

  Future<void> recoverPendingAudioDeletions() => _enqueue(() async {
    if (!ref.mounted) return;
    await ref
        .read(pendingAudioDeletionRecoveryProvider)
        .recover(protectedPaths: _undoableAudioPaths.toSet());
  });

  Iterable<String> get _undoableAudioPaths =>
      _undoableNotes.values.map(_retainedPath).whereType<String>();

  String? _retainedPath(TranscriptNote note) =>
      note.audioOwnership == AudioOwnership.retained ? note.audioPath : null;

  Future<void> _finalizeAudio(String? path) async {
    if (path == null || !ref.mounted || _undoableAudioPaths.contains(path)) {
      return;
    }
    await ref.read(pendingAudioDeletionRecoveryProvider).finalize(path);
  }

  void _publish(List<TranscriptNote> notes) {
    if (ref.mounted) state = notes;
  }

  void _invalidateHistory() {
    if (ref.mounted && ref.read(historyControllerProvider.exists)) {
      ref.read(historyControllerProvider.notifier).retry();
    }
  }

  void _cache(TranscriptNote note) {
    if (!ref.mounted) return;
    _publish([note, ...state.where((cached) => cached.id != note.id).take(7)]);
  }

  void _evict(String id) {
    if (!ref.mounted) return;
    if (byId(id) != null) {
      _publish(state.where((note) => note.id != id).toList());
    }
    ref.invalidate(noteDeletionRevisionProvider(id));
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final next = _pending.then((_) => operation());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  TranscriptNote? byId(String id) => noteById(state, id);

  Future<TodoItem?> toggleTodo(String noteId, int index) => _enqueue(() async {
    final todo = await ref
        .read(notesRepositoryProvider)
        .toggleTodo(noteId, index);
    if (!ref.mounted) return todo;
    final cached = byId(noteId);
    if (cached != null) {
      final updated = patchNoteTodo(cached, index, todo);
      if (updated == null) {
        _evict(noteId);
      } else {
        _cache(updated);
      }
    }
    return todo;
  });
}

TranscriptNote? noteById(List<TranscriptNote> notes, String id) {
  for (final note in notes) {
    if (note.id == id) return note;
  }
  return null;
}

TranscriptNote? patchNoteTodo(TranscriptNote note, int index, TodoItem? todo) {
  if (todo == null ||
      index < 0 ||
      index >= note.todos.length ||
      note.todos[index].text != todo.text) {
    return null;
  }
  final todos = [...note.todos]..[index] = todo;
  return note.copyWith(todos: todos);
}

final notesControllerProvider =
    NotifierProvider<NotesController, List<TranscriptNote>>(
      NotesController.new,
    );

final notesPeerRevisionProvider = Provider<Object>((ref) => Object());
final noteDeletionRevisionProvider = Provider.autoDispose
    .family<Object, String>((ref, id) => Object());
