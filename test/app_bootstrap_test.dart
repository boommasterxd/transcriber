import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/app_bootstrap.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/database/legacy_preferences_migrator.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/storage_paths.dart';

import 'support/database_query_trace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _registerBootstrapQueryTest();
  _registerAudioRecoveryTest();
  _registerShareRecoveryTest();
}

void _registerBootstrapQueryTest() {
  test('bootstrap omits persisted note history and detail reads', () async {
    final fixture = await _createQueryBootstrapFixture();
    final bootstrap = await loadAppBootstrap(
      database: fixture.database,
      preferences: await SharedPreferences.getInstance(),
      cacheManager: fixture.cacheManager,
    );

    expect(bootstrap.notes, isEmpty);
    expect(bootstrap.database, same(fixture.database));
    expect(bootstrap.cacheManager, same(fixture.cacheManager));
    _expectNoNoteTableReads(fixture.trace.selects);
    expect(
      (await fixture.repository.findById('persisted'))!.fullTranscriptText,
      'Long persisted transcript',
    );
  });
}

void _registerAudioRecoveryTest() {
  test(
    'regular bootstrap deletes queued audio and preserves previews',
    () async {
      final fixture = await _createQueuedAudioFixture(
        rootPrefix: 'bootstrap_audio_',
        noteId: 'deleted-audio',
        includePreview: true,
      );

      await fixture.bootstrap();

      expect(await fixture.queuedAudio.exists(), isFalse);
      expect(await fixture.previewAudio!.exists(), isTrue);
      expect(await fixture.repository.pendingAudioDeletionPaths(), isEmpty);
    },
  );
}

void _registerShareRecoveryTest() {
  test('share bootstrap leaves queued retained audio untouched', () async {
    final fixture = await _createQueuedAudioFixture(
      rootPrefix: 'share_audio_',
      noteId: 'share-queued-audio',
    );

    await fixture.bootstrap(recoverPendingAudioDeletes: false);

    expect(await fixture.queuedAudio.exists(), isTrue);
    expect(await fixture.repository.pendingAudioDeletionPaths(), [
      fixture.queuedAudio.path,
    ]);
  });
}

Future<_QueryBootstrapFixture> _createQueryBootstrapFixture() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final trace = DatabaseQueryTrace();
  final database = AppDatabase(NativeDatabase.memory().interceptWith(trace));
  addTearDown(database.close);
  await _markLegacyMigrationComplete(database);
  final repository = NotesRepository(database);
  await repository.add(
    TranscriptNote.fromJson({
      'id': 'persisted',
      'title': 'Existing note',
      'createdAt': '2026-01-01',
      'transcript': [
        {'text': 'Long persisted transcript'},
      ],
    }),
  );
  trace.selects.clear();
  final root = await Directory.systemTemp.createTemp('bootstrap_');
  addTearDown(() => root.delete(recursive: true));
  final cacheManager = AudioCacheManager(
    paths: Future.value(
      StoragePaths(
        supportRoot: Directory('${root.path}/support'),
        cacheRoot: Directory('${root.path}/cache'),
      ),
    ),
  );
  return _QueryBootstrapFixture(
    database: database,
    trace: trace,
    repository: repository,
    cacheManager: cacheManager,
  );
}

Future<_QueuedAudioFixture> _createQueuedAudioFixture({
  required String rootPrefix,
  required String noteId,
  bool includePreview = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  await _markLegacyMigrationComplete(database);
  final root = await Directory.systemTemp.createTemp(rootPrefix);
  addTearDown(() => root.delete(recursive: true));
  final paths = StoragePaths(
    supportRoot: Directory('${root.path}/support'),
    cacheRoot: Directory('${root.path}/cache'),
  );
  final cacheManager = AudioCacheManager(paths: Future.value(paths));
  final retained = await paths.retainedAudioDir();
  final queuedAudio = File('${retained.path}/queued.wav');
  await queuedAudio.writeAsBytes([1, 2, 3]);
  final previewAudio = includePreview
      ? File('${retained.path}/uncommitted-preview.wav')
      : null;
  if (previewAudio != null) await previewAudio.writeAsBytes([4, 5, 6]);
  final repository = NotesRepository(database);
  final note = TranscriptNote.fromJson({
    'id': noteId,
    'title': 'Deleted audio',
    'createdAt': '2026-01-01',
    'audioPath': queuedAudio.path,
    'audioOwnership': 'retained',
  });
  await repository.add(note);
  await repository.remove(note.id);
  return _QueuedAudioFixture(
    database: database,
    cacheManager: cacheManager,
    queuedAudio: queuedAudio,
    previewAudio: previewAudio,
    repository: repository,
  );
}

void _expectNoNoteTableReads(List<(String, List<Object?>)> queries) {
  final statements = queries.map((query) => query.$1).join('\n');
  for (final table in [
    'notes',
    'note_points',
    'note_todos',
    'transcript_segments',
  ]) {
    expect(statements, isNot(contains('FROM "$table"')));
    expect(statements, isNot(contains('FROM $table ')));
  }
}

Future<void> _markLegacyMigrationComplete(AppDatabase database) => database
    .into(database.migrationStateTable)
    .insert(
      MigrationStateTableCompanion.insert(
        key: LegacyPreferencesMigrator.marker,
        completedAt: 1,
      ),
    );

final class _QueryBootstrapFixture {
  const _QueryBootstrapFixture({
    required this.database,
    required this.trace,
    required this.repository,
    required this.cacheManager,
  });

  final AppDatabase database;
  final DatabaseQueryTrace trace;
  final NotesRepository repository;
  final AudioCacheManager cacheManager;
}

final class _QueuedAudioFixture {
  const _QueuedAudioFixture({
    required this.database,
    required this.cacheManager,
    required this.queuedAudio,
    required this.previewAudio,
    required this.repository,
  });

  final AppDatabase database;
  final AudioCacheManager cacheManager;
  final File queuedAudio;
  final File? previewAudio;
  final NotesRepository repository;

  Future<void> bootstrap({bool recoverPendingAudioDeletes = true}) async {
    await loadAppBootstrap(
      database: database,
      preferences: await SharedPreferences.getInstance(),
      cacheManager: cacheManager,
      recoverPendingAudioDeletes: recoverPendingAudioDeletes,
    );
  }
}
