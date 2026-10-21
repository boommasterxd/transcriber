import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';

void main() {
  test(
    'v1 to v5 removes segment timestamps without losing note content',
    () async {
      final database = AppDatabase(
        NativeDatabase.memory(
          setup: (database) => _seedV1Schema(database.execute),
        ),
      );
      addTearDown(database.close);

      final segments = await database
          .customSelect(
            'SELECT note_id, position, text FROM transcript_segments '
            'ORDER BY position',
          )
          .get();
      final note = await database
          .customSelect('SELECT id, title FROM notes')
          .getSingle();
      final columns = await database
          .customSelect('PRAGMA table_info(transcript_segments)')
          .get();

      expect(database.schemaVersion, 5);
      expect(note.read<String>('id'), 'note-1');
      expect(note.read<String>('title'), 'Preserved note');
      expect(
        segments.map(
          (row) => (
            row.read<String>('note_id'),
            row.read<int>('position'),
            row.read<String>('text'),
          ),
        ),
        [('note-1', 0, 'First segment'), ('note-1', 1, 'Second segment')],
      );
      expect(columns.map((row) => row.read<String>('name')), [
        'note_id',
        'position',
        'text',
      ]);
      expect(
        (await database.customSelect('PRAGMA foreign_keys').getSingle())
            .read<int>('foreign_keys'),
        1,
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      await expectLater(
        database.customStatement(
          "INSERT INTO transcript_segments VALUES ('missing', 0, 'Orphan')",
        ),
        throwsA(isA<SqliteException>()),
      );
    },
  );

  test(
    'v2 to v5 preserves notes and defaults summary errors to null',
    () async {
      final database = AppDatabase(
        NativeDatabase.memory(
          setup: (database) => _seedV2Schema(database.execute),
        ),
      );
      addTearDown(database.close);

      final note = (await NotesRepository(database).load()).single;

      expect(database.schemaVersion, 5);
      expect(note.id, 'note-1');
      expect(note.title, 'Preserved note');
      expect(note.summaryError, isNull);
      expect(note.fullTranscriptText, 'Original transcript');
      expect(note.gist, 'Original summary');
      expect(note.points, ['Original point']);
      expect(note.todos.single.text, 'Original todo');
      expect(note.todos.single.done, isTrue);
      expect(note.audioPath, '/external/recording.m4a');

      await NotesRepository(
        database,
      ).saveAll([note.copyWith(summaryError: 'Summary failed')]);
      final restored = (await NotesRepository(database).load()).single;
      expect(restored.summaryError, 'Summary failed');
      expect(restored.fullTranscriptText, note.fullTranscriptText);
    },
  );

  _registerHistoryMigrationTests();
  _registerRecoveryMigrationTests();
  _registerFailureMigrationTests();
}

void _registerHistoryMigrationTests() {
  test(
    'v3 migration adds a usable history index and preserves child data',
    () async {
      final database = AppDatabase(
        NativeDatabase.memory(
          setup: (sqlite) {
            _seedV2Schema(sqlite.execute);
            sqlite.execute('ALTER TABLE notes ADD COLUMN summary_error TEXT');
            sqlite.execute('PRAGMA user_version = 3');
          },
        ),
      );
      addTearDown(database.close);
      final page = await NotesRepository(database).loadHistoryPage();
      expect(page.entries.single.id, 'note-1');
      expect(page.entries.single.todoCount, 1);
      expect(
        (await NotesRepository(
          database,
        ).loadHistoryPage(query: 'PRESERVED')).entries.single.id,
        'note-1',
      );
      final plan = await database
          .customSelect(
            'EXPLAIN QUERY PLAN SELECT id FROM notes ORDER BY created_at DESC, id DESC LIMIT 51',
          )
          .get();
      expect(
        plan.map((row) => row.read<String>('detail')).join(),
        contains('notes_history_order'),
      );
      final note = await NotesRepository(database).findById('note-1');
      expect(note!.points, ['Original point']);
      expect(note.fullTranscriptText, 'Original transcript');
    },
  );

  test(
    'title migration uses bounded batches and preserves Unicode search',
    () async {
      final database = AppDatabase(
        NativeDatabase.memory(
          setup: (sqlite) {
            _seedV2Schema(sqlite.execute);
            sqlite.execute('ALTER TABLE notes ADD COLUMN summary_error TEXT');
            for (var index = 0; index < 130; index++) {
              sqlite.execute(
                "INSERT INTO notes SELECT 'bulk-$index', 'ÄPFEL', speaker, source, "
                'duration_sec, created_at, asr_is_local, summary_is_local, asr_name, '
                'asr_sub, llm_name, llm_sub, gist, audio_path, audio_ownership, '
                "summary_error FROM notes WHERE id = 'note-1'",
              );
            }
            sqlite.execute('PRAGMA user_version = 3');
          },
        ),
      );
      addTearDown(database.close);
      final page = await NotesRepository(
        database,
      ).loadHistoryPage(query: 'äpfel');
      expect(page.totalCount, 130);
      expect(page.entries, hasLength(50));
    },
  );
}

void _registerRecoveryMigrationTests() {
  test('v4 to v5 creates the durable audio-deletion queue', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (sqlite) {
          _seedV2Schema(sqlite.execute);
          sqlite.execute('ALTER TABLE notes ADD COLUMN summary_error TEXT');
          sqlite.execute(
            "ALTER TABLE notes ADD COLUMN title_search TEXT NOT NULL DEFAULT ''",
          );
          sqlite.execute(
            'CREATE INDEX notes_history_order ON notes (created_at DESC, id DESC)',
          );
          sqlite.execute('PRAGMA user_version = 4');
        },
      ),
    );
    addTearDown(database.close);

    expect(
      await database
          .customSelect('SELECT path FROM pending_audio_deletions')
          .get(),
      isEmpty,
    );
    final plan = await database
        .customSelect(
          "EXPLAIN QUERY PLAN SELECT id FROM notes WHERE audio_path = '/retained/voice.wav' "
          "AND audio_ownership = 'retained' LIMIT 1",
        )
        .get();
    expect(
      plan.map((row) => row.read<String>('detail')).join(),
      contains('notes_audio_path'),
    );
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      5,
    );
  });
}

void _registerFailureMigrationTests() {
  _registerBackfillRollbackTest();
  _registerPartialMigrationTests();
}

void _registerBackfillRollbackTest() {
  test('failed title backfill rolls back and a later open can migrate', () async {
    final directory = await Directory.systemTemp.createTemp(
      'transcriber-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/notes.sqlite');
    final failed = AppDatabase(
      NativeDatabase(
        file,
        setup: (sqlite) {
          _seedV2Schema(sqlite.execute);
          sqlite.execute(
            'CREATE TRIGGER fail_title_backfill BEFORE UPDATE OF title_search '
            "ON notes BEGIN SELECT RAISE(ABORT, 'synthetic backfill failure'); END",
          );
        },
      ),
    );
    await expectLater(
      failed.customSelect('SELECT id FROM notes').get(),
      throwsA(
        isA<SqliteException>().having(
          (error) => error.message,
          'message',
          contains('synthetic backfill failure'),
        ),
      ),
    );
    await failed.close();

    var inspectedRollback = false;
    final restarted = AppDatabase(
      NativeDatabase(
        file,
        setup: (sqlite) {
          expect(sqlite.userVersion, 2);
          final columns = sqlite.select('PRAGMA table_info(notes)');
          expect(
            columns.map((row) => row['name']),
            isNot(contains('title_search')),
          );
          expect(
            columns.map((row) => row['name']),
            isNot(contains('summary_error')),
          );
          expect(
            sqlite.select(
              "SELECT name FROM sqlite_master WHERE name = 'notes_history_order'",
            ),
            isEmpty,
          );
          sqlite.execute('DROP TRIGGER fail_title_backfill');
          inspectedRollback = true;
        },
      ),
    );
    addTearDown(restarted.close);
    final note = await NotesRepository(restarted).findById('note-1');
    expect(inspectedRollback, isTrue);
    expect(note?.title, 'Preserved note');
    expect(note?.points, ['Original point']);
    expect(note?.todos.single.text, 'Original todo');
    expect(note?.fullTranscriptText, 'Original transcript');
    expect(restarted.schemaVersion, 5);
    expect(
      (await restarted.customSelect('PRAGMA foreign_keys').getSingle())
          .read<int>('foreign_keys'),
      1,
    );
    expect(
      (await restarted.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      5,
    );
  });
}

void _registerPartialMigrationTests() {
  test('partially applied old v3 upgrade preserves summary errors', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (sqlite) {
          _seedV2Schema(sqlite.execute);
          sqlite.execute('ALTER TABLE notes ADD COLUMN summary_error TEXT');
          sqlite.execute(
            "UPDATE notes SET summary_error = 'Preserved failure'",
          );
        },
      ),
    );
    addTearDown(database.close);

    final note = await NotesRepository(database).findById('note-1');
    expect(note?.summaryError, 'Preserved failure');
    expect(note?.fullTranscriptText, 'Original transcript');
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      5,
    );
  });

  test('partially applied old v4 upgrade is repaired on restart', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (sqlite) {
          _seedV2Schema(sqlite.execute);
          sqlite.execute('ALTER TABLE notes ADD COLUMN summary_error TEXT');
          sqlite.execute(
            "ALTER TABLE notes ADD COLUMN title_search TEXT NOT NULL DEFAULT ''",
          );
          sqlite.execute("UPDATE notes SET title_search = 'incomplete'");
          sqlite.execute(
            'CREATE INDEX notes_history_order ON notes (created_at DESC, id DESC)',
          );
          sqlite.execute('PRAGMA user_version = 3');
        },
      ),
    );
    addTearDown(database.close);

    final note = await NotesRepository(
      database,
    ).loadHistoryPage(query: 'preserved');
    expect(note.entries.single.id, 'note-1');
    expect(database.schemaVersion, 5);
    expect(
      await database
          .customSelect('SELECT path FROM pending_audio_deletions')
          .get(),
      isEmpty,
    );
  });
}

void _seedV2Schema(void Function(String) execute) {
  execute(
    'CREATE TABLE app_settings ('
    'id INTEGER NOT NULL PRIMARY KEY, theme_mode TEXT NOT NULL, '
    'accent TEXT NOT NULL, language TEXT NOT NULL, '
    'transcription_language TEXT NOT NULL, asr_provider TEXT NOT NULL, '
    'summary_provider TEXT NOT NULL, asr_model TEXT NOT NULL, '
    'summary_model TEXT NOT NULL, auto_delete_audio INTEGER NOT NULL, '
    'summarize_enabled INTEGER NOT NULL, onboarded INTEGER NOT NULL)',
  );
  execute(
    'CREATE TABLE migration_state ('
    'key TEXT NOT NULL PRIMARY KEY, completed_at INTEGER NOT NULL)',
  );
  execute(
    'CREATE TABLE notes ('
    'id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL, '
    'speaker TEXT NOT NULL, source TEXT NOT NULL, '
    'duration_sec INTEGER NOT NULL, created_at INTEGER NOT NULL, '
    'asr_is_local INTEGER NOT NULL, summary_is_local INTEGER NOT NULL, '
    'asr_name TEXT NOT NULL, asr_sub TEXT NOT NULL, '
    'llm_name TEXT NOT NULL, llm_sub TEXT NOT NULL, gist TEXT NOT NULL, '
    'audio_path TEXT, audio_ownership TEXT NOT NULL)',
  );
  for (final table in ['note_points', 'note_todos', 'transcript_segments']) {
    final todoColumn = table == 'note_todos' ? ', done INTEGER NOT NULL' : '';
    execute(
      'CREATE TABLE $table ('
      'note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE, '
      'position INTEGER NOT NULL, text TEXT NOT NULL$todoColumn, '
      'PRIMARY KEY (note_id, position))',
    );
  }
  execute(
    "INSERT INTO notes VALUES ('note-1', 'Preserved note', 'Speaker', "
    "'recording', 42, 1735689600000, 0, 0, 'ASR', 'Cloud', 'LLM', "
    "'Cloud', 'Original summary', '/external/recording.m4a', 'external')",
  );
  execute("INSERT INTO note_points VALUES ('note-1', 0, 'Original point')");
  execute("INSERT INTO note_todos VALUES ('note-1', 0, 'Original todo', 1)");
  execute(
    "INSERT INTO transcript_segments VALUES ('note-1', 0, 'Original transcript')",
  );
  execute('PRAGMA user_version = 2');
}

void _seedV1Schema(void Function(String) execute) {
  _seedV2Schema(execute);
  execute('DROP TABLE transcript_segments');
  execute(
    'CREATE TABLE transcript_segments ('
    'note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE, '
    'position INTEGER NOT NULL, '
    'time TEXT NOT NULL, '
    'text TEXT NOT NULL, '
    'PRIMARY KEY (note_id, position)'
    ')',
  );
  execute(
    "INSERT INTO transcript_segments (note_id, position, time, text) VALUES "
    "('note-1', 0, '00:00', 'First segment'), "
    "('note-1', 1, '00:05', 'Second segment')",
  );
  execute('PRAGMA user_version = 1');
  execute('PRAGMA foreign_keys = ON');
}
