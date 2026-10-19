import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';

void main() {
  test(
    'v1 to v4 removes segment timestamps without losing note content',
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

      expect(database.schemaVersion, 4);
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
    },
  );

  test(
    'v2 to v4 preserves notes and defaults summary errors to null',
    () async {
      final database = AppDatabase(
        NativeDatabase.memory(
          setup: (database) => _seedV2Schema(database.execute),
        ),
      );
      addTearDown(database.close);

      final note = (await NotesRepository(database).load()).single;

      expect(database.schemaVersion, 4);
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

void _seedV2Schema(void Function(String) execute) {
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
  execute('PRAGMA foreign_keys = ON');
  execute(
    'CREATE TABLE notes ('
    'id TEXT NOT NULL PRIMARY KEY, '
    'title TEXT NOT NULL, created_at INTEGER NOT NULL DEFAULT 0'
    ')',
  );
  execute(
    'CREATE TABLE transcript_segments ('
    'note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE, '
    'position INTEGER NOT NULL, '
    'time TEXT NOT NULL, '
    'text TEXT NOT NULL, '
    'PRIMARY KEY (note_id, position)'
    ')',
  );
  execute("INSERT INTO notes (id, title) VALUES ('note-1', 'Preserved note')");
  execute(
    "INSERT INTO transcript_segments (note_id, position, time, text) VALUES "
    "('note-1', 0, '00:00', 'First segment'), "
    "('note-1', 1, '00:05', 'Second segment')",
  );
  execute('PRAGMA user_version = 1');
}
