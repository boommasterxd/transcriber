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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.alterTable(TableMigration(transcriptSegmentsTable));
      }
      if (from < 3) {
        await migrator.addColumn(notesTable, notesTable.summaryError);
      }
      if (from < 4) {
        await migrator.addColumn(notesTable, notesTable.titleSearch);
        await _populateTitleSearch();
        await customStatement(
          'CREATE INDEX notes_history_order ON notes (created_at DESC, id DESC)',
        );
      }
    },
  );

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
