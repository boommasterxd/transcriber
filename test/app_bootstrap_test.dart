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

  test(
    'main and share bootstrap omit persisted note history and detail reads',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final trace = DatabaseQueryTrace();
      final database = AppDatabase(
        NativeDatabase.memory().interceptWith(trace),
      );
      addTearDown(database.close);
      await database
          .into(database.migrationStateTable)
          .insert(
            MigrationStateTableCompanion.insert(
              key: LegacyPreferencesMigrator.marker,
              completedAt: 1,
            ),
          );
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
      final cache = AudioCacheManager(
        paths: Future.value(
          StoragePaths(
            supportRoot: Directory('${root.path}/support'),
            cacheRoot: Directory('${root.path}/cache'),
          ),
        ),
      );
      final bootstrap = await loadAppBootstrap(
        database: database,
        preferences: await SharedPreferences.getInstance(),
        cacheManager: cache,
      );
      expect(bootstrap.notes, isEmpty);
      expect(bootstrap.database, same(database));
      expect(bootstrap.cacheManager, same(cache));
      final statements = trace.selects.map((query) => query.$1).join('\n');
      for (final table in [
        'notes',
        'note_points',
        'note_todos',
        'transcript_segments',
      ]) {
        expect(statements, isNot(contains('FROM "$table"')));
        expect(statements, isNot(contains('FROM $table ')));
      }
      expect(
        (await repository.findById('persisted'))!.fullTranscriptText,
        'Long persisted transcript',
      );
    },
  );
}
