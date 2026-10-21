import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/managed_audio_file.dart';
import 'package:transcriber/services/storage/pending_audio_deletion_recovery.dart';
import 'package:transcriber/services/storage/storage_paths.dart';

void main() {
  group('pending audio deletion recovery', () {
    late _RecoveryFixture fixture;

    setUp(() async => fixture = await _RecoveryFixture.create());
    tearDown(() => fixture.close());
    _registerQueuedFileRecoveryTest(() => fixture);
    _registerBatchBudgetTest(() => fixture);
    _registerFailureRotationTest(() => fixture);
    _registerSharedReferenceProtectionTest(() => fixture);
    _registerActivePathRetryTest(() => fixture);
  });
}

void _registerQueuedFileRecoveryTest(_RecoveryFixture Function() fixture) {
  test(
    'recovers queued audio after reopening without sweeping retained previews',
    () async {
      final recovery = fixture();
      final retained = await recovery.paths.retainedAudioDir();
      final queued = File(p.join(retained.path, 'deleted.wav'));
      final preview = File(p.join(retained.path, 'preview.wav'));
      await queued.writeAsBytes([1, 2, 3]);
      await preview.writeAsBytes([4, 5, 6]);
      final note = _note('deleted', queued.path);
      await recovery.repository.add(note);
      await recovery.repository.remove(note.id);

      await recovery.reopen();

      expect(await recovery.repository.findById(note.id), isNull);
      expect(await queued.exists(), isTrue);
      expect(await recovery.repository.pendingAudioDeletionPaths(), [
        queued.path,
      ]);
      await recovery.recovery.recover();

      expect(await queued.exists(), isFalse);
      expect(await preview.exists(), isTrue);
      expect(await recovery.repository.pendingAudioDeletionPaths(), isEmpty);
    },
  );
}

void _registerBatchBudgetTest(_RecoveryFixture Function() fixture) {
  test('startup recovery processes one bounded candidate batch', () async {
    final recovery = fixture();
    final retained = await recovery.paths.retainedAudioDir();
    final candidates = List.generate(
      NotesRepository.maxPendingAudioDeletionBatchSize + 1,
      (index) => p.join(
        retained.path,
        'pending-${index.toString().padLeft(3, '0')}.wav',
      ),
    );
    await _queueCandidates(recovery, candidates);

    await recovery.recovery.recover();

    expect(await recovery.repository.pendingAudioDeletionPaths(), [
      candidates.last,
    ]);
    await recovery.recovery.recover();
    expect(await recovery.repository.pendingAudioDeletionPaths(), isEmpty);
  });
}

void _registerFailureRotationTest(_RecoveryFixture Function() fixture) {
  test('failed candidates do not starve later queued audio', () async {
    final recovery = fixture();
    final blocked = await _createActiveCandidates(recovery);
    final retained = await recovery.paths.retainedAudioDir();
    final available = File(p.join(retained.path, 'ready.wav'));
    await available.writeAsBytes([1, 2, 3]);
    await _queueCandidates(recovery, [...blocked, available.path]);

    await recovery.recovery.recover();

    expect(await available.exists(), isTrue);
    await recovery.recovery.recover();

    expect(await available.exists(), isFalse);
    expect(
      await recovery.repository.pendingAudioDeletionPaths(),
      unorderedEquals(blocked),
    );
  });
}

Future<List<String>> _createActiveCandidates(_RecoveryFixture fixture) async {
  final retained = await fixture.paths.retainedAudioDir();
  final paths = <String>[];
  for (
    var index = 0;
    index < NotesRepository.maxPendingAudioDeletionBatchSize;
    index++
  ) {
    final audio = File(p.join(retained.path, 'blocked-$index.wav'));
    await audio.writeAsBytes([1]);
    fixture.cacheManager.markActive(
      ManagedAudioFile(path: audio.path, ownership: AudioOwnership.retained),
    );
    paths.add(audio.path);
  }
  return paths;
}

Future<void> _queueCandidates(
  _RecoveryFixture fixture,
  List<String> candidates,
) => fixture.database.batch((batch) {
  batch.insertAll(fixture.database.pendingAudioDeletionsTable, [
    for (final path in candidates)
      PendingAudioDeletionsTableCompanion.insert(path: path),
  ]);
});

void _registerSharedReferenceProtectionTest(
  _RecoveryFixture Function() fixture,
) {
  test('preserves audio while another note references it', () async {
    final recovery = fixture();
    final retained = await recovery.paths.retainedAudioDir();
    final audio = File(p.join(retained.path, 'shared.wav'));
    await audio.writeAsBytes([1, 2, 3]);
    await recovery.repository.saveAll([
      _note('first', audio.path),
      _note('second', audio.path),
    ]);
    await recovery.repository.remove('first');

    await recovery.recovery.recover();

    expect(await audio.exists(), isTrue);
    expect(await recovery.repository.pendingAudioDeletionPaths(), isEmpty);
  });
}

void _registerActivePathRetryTest(_RecoveryFixture Function() fixture) {
  test('retains an active path for a later retry', () async {
    final recovery = fixture();
    final retained = await recovery.paths.retainedAudioDir();
    final audio = File(p.join(retained.path, 'active.wav'));
    await audio.writeAsBytes([1, 2, 3]);
    final note = _note('active', audio.path);
    await recovery.repository.add(note);
    await recovery.repository.remove(note.id);
    final managed = ManagedAudioFile(
      path: audio.path,
      ownership: AudioOwnership.retained,
    );
    recovery.cacheManager.markActive(managed);

    await recovery.recovery.recover();

    expect(await audio.exists(), isTrue);
    expect(await recovery.repository.pendingAudioDeletionPaths(), [audio.path]);
    recovery.cacheManager.markInactive(managed);
    await recovery.recovery.recover();
    expect(await audio.exists(), isFalse);
    expect(await recovery.repository.pendingAudioDeletionPaths(), isEmpty);
  });
}

TranscriptNote _note(String id, String audioPath) => TranscriptNote(
  metadata: NoteMetadata(
    id: id,
    title: 'Note $id',
    speaker: 'Speaker',
    source: NoteSource.file,
    durationSec: 1,
    createdAt: DateTime.utc(2025),
  ),
  origins: const NoteOrigins(
    asrIsLocal: false,
    summaryIsLocal: false,
    asrName: 'ASR',
    asrSub: 'Provider',
    llmName: 'LLM',
    llmSub: 'Provider',
  ),
  content: const NoteContent(gist: '', points: [], todos: [], transcript: []),
  audioPath: audioPath,
  audioOwnership: AudioOwnership.retained,
);

final class _RecoveryFixture {
  _RecoveryFixture._(this.root, this.paths) {
    _openDatabase();
  }

  final Directory root;
  final StoragePaths paths;
  late AppDatabase database;
  late NotesRepository repository;
  late AudioCacheManager cacheManager;
  late PendingAudioDeletionRecovery recovery;

  static Future<_RecoveryFixture> create() async {
    final root = await Directory.systemTemp.createTemp(
      'audio-delete-recovery-',
    );
    final paths = StoragePaths(
      supportRoot: Directory(p.join(root.path, 'support')),
      cacheRoot: Directory(p.join(root.path, 'cache')),
    );
    return _RecoveryFixture._(root, paths);
  }

  void _openDatabase() {
    database = AppDatabase(
      NativeDatabase(File(p.join(root.path, 'notes.sqlite'))),
    );
    repository = NotesRepository(database);
    cacheManager = AudioCacheManager(paths: Future.value(paths));
    recovery = PendingAudioDeletionRecovery(repository, cacheManager);
  }

  Future<void> reopen() async {
    await database.close();
    _openDatabase();
  }

  Future<void> close() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
