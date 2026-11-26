import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/database/legacy_preferences_migrator.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';

void main() {
  late _MigrationContext context;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    context = _MigrationContext(
      database: AppDatabase(NativeDatabase.memory()),
      preferences: await SharedPreferences.getInstance(),
      secureStorage: const FlutterSecureStorage(),
    );
  });

  tearDown(() => context.database.close());
  _registerMigrationTests(() => context);
}

class _MigrationContext {
  const _MigrationContext({
    required this.database,
    required this.preferences,
    required this.secureStorage,
  });

  final AppDatabase database;
  final SharedPreferences preferences;
  final FlutterSecureStorage secureStorage;

  LegacyPreferencesMigrator migrator({
    SharedPreferences? preferences,
    FlutterSecureStorage? secureStorage,
  }) => LegacyPreferencesMigrator(
    database: database,
    preferences: preferences ?? this.preferences,
    secureStorage: secureStorage ?? this.secureStorage,
  );
}

void _registerMigrationTests(_MigrationContext Function() contextFactory) {
  _registerPartialMigrationTest(contextFactory);
  _registerFailedMigrationTest(contextFactory);
}

void _registerPartialMigrationTest(
  _MigrationContext Function() contextFactory,
) {
  test(
    'partitions mixed notes through interrupted recovery writes and removal',
    () async {
      final context = contextFactory();
      final note = _note('valid');
      final raw = jsonEncode([
        note.toJson(),
        {'id': 'invalid'},
      ]);
      await context.preferences.setString('notes', raw);
      final preferences = _ReadTrackingPreferences(context.preferences);
      final migrator = context.migrator(preferences: preferences);
      preferences.setOverride = (key, value) async => false;

      await migrator.migrate();
      expect(preferences.reads, ['app_settings', 'notes']);
      final imported = await context.database
          .select(context.database.notesTable)
          .get();
      expect(imported.single.id, note.id);
      expect(context.preferences.getString('notes'), raw);
      expect(_recoveredNotes(context), isNull);
      await NotesRepository(context.database).remove(note.id);
      preferences.reads.clear();

      preferences.setOverride = null;
      preferences.removeOverride = (_) async => false;
      await migrator.migrate();
      expect(preferences.reads, ['notes']);
      expect(context.preferences.getString('notes'), raw);
      expect(_recoveredNotes(context), [
        {'id': 'invalid'},
      ]);
      preferences.reads.clear();
      preferences.removeOverride = null;

      await migrator.migrate();
      expect(preferences.reads, isEmpty);
      expect(context.preferences.containsKey('notes'), isFalse);
      expect(_recoveredNotes(context), [
        {'id': 'invalid'},
      ]);
      expect(
        await context.database.select(context.database.notesTable).get(),
        isEmpty,
      );
    },
  );
}

Object? _recoveredNotes(_MigrationContext context) {
  final raw = context.preferences.getString(
    LegacyPreferencesMigrator.rejectedNotesRecoveryKey,
  );
  return raw == null ? null : jsonDecode(raw);
}

void _registerFailedMigrationTest(_MigrationContext Function() contextFactory) {
  test(
    'rolls back failed imports and retries before cleaning legacy data',
    () async {
      final context = contextFactory();
      final note = _note('retry');
      await _seedLegacyStorage(context, note);
      await context.database.customStatement('''
      CREATE TRIGGER reject_legacy_note BEFORE INSERT ON notes
      BEGIN SELECT RAISE(ABORT, 'import unavailable'); END
    ''');

      await expectLater(_migrate(context), throwsA(isA<Exception>()));
      expect(
        await context.database.select(context.database.notesTable).get(),
        isEmpty,
      );
      expect(
        await context.database.select(context.database.appSettingsTable).get(),
        isEmpty,
      );
      expect(
        await context.database
            .select(context.database.migrationStateTable)
            .get(),
        isEmpty,
      );
      expect(context.preferences.containsKey('notes'), isTrue);
      expect(context.preferences.containsKey('app_settings'), isTrue);
      expect(await context.secureStorage.read(key: 'hf_token'), 'legacy-token');

      await context.database.customStatement('DROP TRIGGER reject_legacy_note');
      await _migrate(context);
      await _expectAtomicMigration(context, note);
    },
  );
}

class _ReadTrackingPreferences implements SharedPreferences {
  _ReadTrackingPreferences(this.delegate);

  final SharedPreferences delegate;
  final reads = <String>[];
  Future<bool> Function(String key)? removeOverride;
  Future<bool> Function(String key, String value)? setOverride;

  @override
  Future<void> reload() => delegate.reload();

  @override
  Object? get(String key) => delegate.get(key);

  @override
  String? getString(String key) {
    reads.add(key);
    return delegate.getString(key);
  }

  @override
  Future<bool> remove(String key) =>
      removeOverride?.call(key) ?? delegate.remove(key);

  @override
  Future<bool> setString(String key, String value) =>
      setOverride?.call(key, value) ?? delegate.setString(key, value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _seedLegacyStorage(
  _MigrationContext context,
  TranscriptNote note,
) async {
  await context.preferences.setString(
    'app_settings',
    jsonEncode(
      AppSettings.initial().copyWith(onboarded: true).toJson()
        ..['summaryProvider'] = 'anthropic'
        ..['asrMode'] = 'local',
    ),
  );
  await context.preferences.setString('notes', jsonEncode([note.toJson()]));
  await context.secureStorage.write(key: 'hf_token', value: 'legacy-token');
  await context.secureStorage.write(
    key: 'api_key_anthropic',
    value: 'obsolete-key',
  );
}

Future<void> _migrate(_MigrationContext context) async {
  final migrator = context.migrator();
  if (await migrator.migrate()) await migrator.cleanupObsoleteCredentials();
}

Future<void> _expectAtomicMigration(
  _MigrationContext context,
  TranscriptNote note,
) async {
  final settings = await context.database
      .select(context.database.appSettingsTable)
      .get();
  final notes = await context.database
      .select(context.database.notesTable)
      .get();
  final migrationState = await context.database
      .select(context.database.migrationStateTable)
      .get();

  expect(settings.single.onboarded, isTrue);
  expect(settings.single.summaryProvider, 'google');
  expect(notes.single.id, note.id);
  expect(context.preferences.containsKey('app_settings'), isFalse);
  expect(context.preferences.containsKey('notes'), isFalse);
  expect(await context.secureStorage.read(key: 'hf_token'), isNull);
  expect(await context.secureStorage.read(key: 'api_key_anthropic'), isNull);
  expect(
    migrationState.map((row) => row.key),
    contains(LegacyPreferencesMigrator.marker),
  );
}

TranscriptNote _note(String id) => TranscriptNote(
  metadata: NoteMetadata(
    id: id,
    title: 'Legacy title',
    speaker: 'Legacy speaker',
    source: NoteSource.file,
    durationSec: 12,
    createdAt: DateTime.utc(2025, 1, 1),
  ),
  origins: const NoteOrigins(
    asrIsLocal: true,
    summaryIsLocal: false,
    asrName: 'Whisper Base',
    asrSub: 'Local',
    llmName: 'Gemma',
    llmSub: 'Local',
  ),
  content: NoteContent(
    gist: 'Legacy gist',
    points: const ['Legacy point'],
    todos: [TodoItem(text: 'Legacy todo')],
    transcript: const [TranscriptLine(text: 'Legacy transcript')],
  ),
  audioPath: '/external/legacy.m4a',
);
