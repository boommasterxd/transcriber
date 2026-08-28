import 'package:drift/drift.dart';

class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  IntColumn get id => integer()();
  TextColumn get themeMode => text()();
  TextColumn get accent => text()();
  TextColumn get language => text()();
  TextColumn get transcriptionLanguage => text()();
  TextColumn get asrProvider => text()();
  TextColumn get summaryProvider => text()();
  TextColumn get asrModel => text()();
  TextColumn get summaryModel => text()();
  BoolColumn get autoDeleteAudio => boolean()();
  BoolColumn get summarizeEnabled => boolean()();
  BoolColumn get onboarded => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NotesTable extends Table {
  @override
  String get tableName => 'notes';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get speaker => text()();
  TextColumn get source => text()();
  IntColumn get durationSec => integer()();
  IntColumn get createdAt => integer()();
  BoolColumn get asrIsLocal => boolean()();
  BoolColumn get summaryIsLocal => boolean()();
  TextColumn get asrName => text()();
  TextColumn get asrSub => text()();
  TextColumn get llmName => text()();
  TextColumn get llmSub => text()();
  TextColumn get gist => text()();
  TextColumn get audioPath => text().nullable()();
  TextColumn get audioOwnership => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

abstract class OrderedNoteChildTable extends Table {
  TextColumn get noteId =>
      text().references(NotesTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {noteId, position};
}

class NotePointsTable extends OrderedNoteChildTable {
  @override
  String get tableName => 'note_points';

  TextColumn get content => text().named('text')();
}

class NoteTodosTable extends OrderedNoteChildTable {
  @override
  String get tableName => 'note_todos';

  TextColumn get content => text().named('text')();
  BoolColumn get done => boolean()();
}

class TranscriptSegmentsTable extends OrderedNoteChildTable {
  @override
  String get tableName => 'transcript_segments';

  TextColumn get content => text().named('text')();
}

class MigrationStateTable extends Table {
  @override
  String get tableName => 'migration_state';

  TextColumn get key => text()();
  IntColumn get completedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
