import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AppSettingsTable,
    NotesTable,
    NotePointsTable,
    NoteTodosTable,
    TranscriptSegmentsTable,
    MigrationStateTable,
    PendingAudioDeletionsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults()
    : super(
        driftDatabase(
          name: 'transcriber',
          native: const DriftNativeOptions(shareAcrossIsolates: true),
        ),
      );

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await customStatement('PRAGMA user_version = $schemaVersion');
    }),
    onUpgrade: (migrator, from, to) async {
      // SQLite ignores this pragma inside a transaction. The v1 table rebuild
      // must run with foreign keys disabled, including preconfigured connections.
      await customStatement('PRAGMA foreign_keys = OFF');
      await transaction(() => _upgradeSchema(migrator, from));
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> _upgradeSchema(Migrator migrator, int from) async {
    if (from < 2) {
      await migrator.alterTable(TableMigration(transcriptSegmentsTable));
    }
    if (from < 3 && !await _notesColumnExists('summary_error')) {
      await migrator.addColumn(notesTable, notesTable.summaryError);
    }
    if (from < 4) {
      if (!await _notesColumnExists('title_search')) {
        await migrator.addColumn(notesTable, notesTable.titleSearch);
      }
      await _populateTitleSearch();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS notes_history_order '
        'ON notes (created_at DESC, id DESC)',
      );
    }
    if (from < 5) {
      await migrator.createTable(pendingAudioDeletionsTable);
      await customStatement(
        'CREATE INDEX IF NOT EXISTS notes_audio_path ON notes (audio_path)',
      );
    }
    // Drift writes this again after onUpgrade returns. Keeping it inside the
    // transaction makes schema changes and the version marker atomic.
    await customStatement('PRAGMA user_version = $schemaVersion');
  }

  Future<bool> _notesColumnExists(String name) async {
    final columns = await customSelect('PRAGMA table_info(notes)').get();
    return columns.any((row) => row.read<String>('name') == name);
  }

  /// Backfills only titles in bounded batches, preserving Dart Unicode casing.
  Future<void> _populateTitleSearch() async {
    String? cursor;
    while (true) {
      final rows = await customSelect(
        'SELECT id, title FROM notes '
        '${cursor == null ? '' : 'WHERE id > ? '}'
        'ORDER BY id LIMIT 128',
        variables: [if (cursor != null) Variable(cursor)],
      ).get();
      if (rows.isEmpty) return;
      for (final row in rows) {
        await customStatement(
          'UPDATE notes SET title_search = ? WHERE id = ?',
          [row.read<String>('title').toLowerCase(), row.read<String>('id')],
        );
      }
      cursor = rows.last.read<String>('id');
    }
  }
}
