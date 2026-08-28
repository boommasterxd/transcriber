import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';

void main() {
  test(
    'v1 to v2 removes segment timestamps without losing note content',
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

      expect(database.schemaVersion, 2);
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
}

void _seedV1Schema(void Function(String) execute) {
  execute('PRAGMA foreign_keys = ON');
  execute(
    'CREATE TABLE notes ('
    'id TEXT NOT NULL PRIMARY KEY, '
    'title TEXT NOT NULL'
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
