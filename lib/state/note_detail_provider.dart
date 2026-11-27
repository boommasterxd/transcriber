import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/transcript_note.dart';
import 'notes_controller.dart';
import 'providers.dart';

/// Detail data lives only while its route/pane is observed.
final noteDetailProvider = AsyncNotifierProvider.autoDispose
    .family<NoteDetailController, TranscriptNote?, String>(
      NoteDetailController.new,
      retry: (_, _) => null,
    );

class NoteDetailController extends AsyncNotifier<TranscriptNote?> {
  NoteDetailController(this._id);

  final String _id;

  @override
  Future<TranscriptNote?> build() async {
    final scope = ref;
    ref.watch(notesPeerRevisionProvider);
    ref.watch(noteDeletionRevisionProvider(_id));
    final cached = ref.watch(
      notesControllerProvider.select((notes) => noteById(notes, _id)),
    );
    final controller = ref.read(notesControllerProvider.notifier);
    final repository = ref.read(notesRepositoryProvider);
    await controller.trackPeerRevision();
    if (!scope.mounted) return null;
    return cached ?? await repository.findById(_id);
  }

  Future<void> toggleTodo(int index) async {
    final scope = ref;
    final controller = scope.read(notesControllerProvider.notifier);
    final todo = await controller.toggleTodo(_id, index);
    if (!scope.mounted) return;
    final detail = state;
    final note = detail.value;
    if (!scope.mounted || note == null) return;
    final updated = patchNoteTodo(note, index, todo);
    if (updated == null || detail.isLoading) {
      scope.invalidateSelf();
    } else {
      state = AsyncData(updated);
    }
  }
}
