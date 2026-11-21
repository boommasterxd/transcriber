import '../../data/repositories/notes_repository.dart';
import 'audio_cache_manager.dart';

/// Finalizes retained-audio deletions recorded with note removal.
final class PendingAudioDeletionRecovery {
  const PendingAudioDeletionRecovery(this._notesRepository, this._cacheManager);

  final NotesRepository _notesRepository;
  final AudioCacheManager _cacheManager;

  /// Retries at most one bounded batch of explicit deletion candidates.
  /// Failed attempts move behind other queued paths for the next startup.
  /// Unrelated retained files stay untouched because they may belong to an
  /// unsaved share preview; remaining candidates wait for the next startup.
  Future<void> recover() async {
    final paths = await _notesRepository.pendingAudioDeletionPaths(
      limit: NotesRepository.maxPendingAudioDeletionBatchSize,
    );
    for (final path in paths) {
      await _process(path);
    }
  }

  /// Completes a note deletion once its undo window has closed.
  Future<void> finalize(String? path) async {
    if (path == null) return;
    await _process(path);
  }

  Future<void> _process(String path) async {
    await _notesRepository.tryProcessPendingAudioDeletion(
      path,
      _cacheManager.tryDeleteRetainedPath,
    );
  }
}
