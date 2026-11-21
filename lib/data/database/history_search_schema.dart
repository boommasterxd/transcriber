import 'package:drift/drift.dart';

/// Runs inside the schema transaction after title normalization.
Future<void> createHistorySearchSchema(GeneratedDatabase database) async {
  final availability = await database
      .customSelect(
        "SELECT sqlite_compileoption_used('ENABLE_FTS5') AS enabled",
      )
      .getSingle();
  final indexTitles = availability.read<int>('enabled') == 1;
  await database.customStatement(
    'CREATE TABLE notes_history_state ('
    'singleton INTEGER PRIMARY KEY CHECK (singleton = 1), '
    'revision INTEGER NOT NULL CHECK (revision >= 0), '
    'title_index INTEGER NOT NULL CHECK (title_index IN (0, 1)))',
  );
  await database.customStatement(
    'INSERT INTO notes_history_state VALUES (1, 0, ?)',
    [indexTitles ? 1 : 0],
  );
  if (indexTitles) {
    await database.customStatement(
      "CREATE VIRTUAL TABLE notes_title_search USING fts5(title_search, "
      "content='notes', tokenize='trigram case_sensitive 1')",
    );
    await database.customStatement(
      "INSERT INTO notes_title_search(notes_title_search) VALUES ('rebuild')",
    );
    await database.customStatement(
      'INSERT INTO notes_title_search(notes_title_search, rank) '
      "VALUES ('secure-delete', 1)",
    );
  }
  await _createHistoryTriggers(database, indexTitles);
}

Future<void> _createHistoryTriggers(
  GeneratedDatabase database,
  bool indexTitles,
) async {
  const addTitle =
      'INSERT INTO notes_title_search(rowid, title_search) '
      'VALUES (new.rowid, new.title_search);';
  const removeTitle =
      'INSERT INTO notes_title_search(notes_title_search, rowid, title_search) '
      "VALUES ('delete', old.rowid, old.title_search);";
  final changes = {
    'insert': ('INSERT', indexTitles ? addTitle : ''),
    'delete': ('DELETE', indexTitles ? removeTitle : ''),
    'update': (
      'UPDATE OF title_search',
      indexTitles ? '$removeTitle $addTitle' : '',
    ),
  };
  for (final MapEntry(key: name, value: (event, indexSql)) in changes.entries) {
    await database.customStatement(
      'CREATE TRIGGER notes_history_$name AFTER $event ON notes BEGIN '
      'UPDATE notes_history_state SET revision = revision + 1; '
      '$indexSql END',
    );
  }
}
