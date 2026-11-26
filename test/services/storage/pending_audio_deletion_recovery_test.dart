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
    _registerStagedPromotionRecoveryTest(() => fixture);
    _registerSharedReferenceProtectionTest(() => fixture);
  });
}

void _registerStagedPromotionRecoveryTest(_RecoveryFixture Function() fixture) {
  test('failed note commit leaves promoted audio recoverable', () async {
    final recovery = fixture();
    final retained = await recovery.paths.retainedAudioDir();
    final staging = await recovery.paths.recordingCacheDir();
    final target = File(p.join(retained.path, 'target.wav'));
    final staged = File(p.join(staging.path, 'staged.wav'));
    final note = _note('new-note', target.path);
    Future<void> promote() async {
      await staged.rename(target.path);
    }

    await staged.writeAsBytes([1, 2, 3]);
    await recovery.database.customStatement(
      "CREATE TRIGGER reject_new_note BEFORE INSERT ON notes "
      "BEGIN SELECT RAISE(ABORT, 'synthetic write failure'); END",
    );
    await expectLater(
      recovery.repository.addWithStagedAudio(note, promote),
      throwsA(isA<SqliteException>()),
    );
    await recovery.reopen();
    expect(await recovery.repository.findById(note.id), isNull);
    expect(await recovery.repository.pendingAudioDeletionPaths(), [
      target.path,
    ]);
    expect(await target.exists(), isTrue);
    await recovery.recovery.recover();
    expect(await target.exists(), isFalse);

    await recovery.database.customStatement('DROP TRIGGER reject_new_note');
    await staged.writeAsBytes([1, 2, 3]);
    await recovery.repository.addWithStagedAudio(note, promote);
    expect(
      (await recovery.repository.findById(note.id))?.audioPath,
      target.path,
    );
    expect(await recovery.repository.pendingAudioDeletionPaths(), isEmpty);
    await recovery.recovery.recover();
    expect(await target.readAsBytes(), [1, 2, 3]);
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
