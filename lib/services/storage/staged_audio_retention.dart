import 'dart:io';

import 'bounded_audio_copy.dart';
import 'managed_audio_file.dart';

/// Holds a bounded copy in temporary storage until the note can commit it.
final class StagedAudioRetention {
  const StagedAudioRetention({
    required this.destination,
    required this._source,
    required this._stage,
    required this._maximumBytes,
  });

  final ManagedAudioFile destination;
  final File _source;
  final File _stage;
  final int _maximumBytes;

  /// Reuses an intact stage or recreates it after rollback and startup recovery.
  Future<void> prepare() async {
    if (await _stage.exists() || await File(destination.path).exists()) return;
    final partial = File('${_stage.path}.partial');
    try {
      await copyAudioWithinLimit(_source, partial, _maximumBytes);
      await partial.rename(_stage.path);
    } finally {
      await _deleteStageFile(partial);
    }
  }

  /// Publishes the file inside the repository's guarded save transaction.
  Future<void> promote() async {
    if (await File(destination.path).exists()) return;
    await _stage.rename(destination.path);
  }

  Future<void> discardStage() => _deleteStageFile(_stage);

  Future<void> _deleteStageFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Startup also expires interrupted staging copies.
    }
  }
}
