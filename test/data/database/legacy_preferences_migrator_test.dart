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
  _registerAtomicMigrationTest(contextFactory);
  _registerMalformedPayloadTest(contextFactory);
  _registerCompletedMigrationTest(contextFactory);
  _registerInterruptedPreferenceCleanupTest(contextFactory);
  _registerInterruptedCredentialCleanupTest(contextFactory);
  _registerPartialMigrationTest(contextFactory);
  _registerFailedMigrationTest(contextFactory);
}

void _registerCompletedMigrationTest(
  _MigrationContext Function() contextFactory,
) {
  test(
    'classifies old migration leftovers once without reimporting notes',
    () async {
      final context = contextFactory();
      await context.database
          .into(context.database.migrationStateTable)
          .insert(
            MigrationStateTableCompanion.insert(
              key: LegacyPreferencesMigrator.marker,
              completedAt: 1,
            ),
          );
      await context.database
          .into(context.database.migrationStateTable)
          .insert(
            MigrationStateTableCompanion.insert(
              key: '${LegacyPreferencesMigrator.marker}_cleanup_classified',
              completedAt: 1,
            ),
          );
      final repository = NotesRepository(context.database);
      await repository.add(_note('current'));
      final rawNotes = jsonEncode([
        _note('old').toJson(),
        {'id': 'invalid'},
      ]);
      await context.preferences.setString('notes', rawNotes);
      await context.preferences.setString(
        LegacyPreferencesMigrator.rejectedNotesRecoveryKey,
        'prior malformed recovery',
      );
      final preferences = _ReadTrackingPreferences(context.preferences);

      final migrator = context.migrator(preferences: preferences);

      await migrator.migrate();
      expect(preferences.reads, ['notes']);
      expect(context.preferences.containsKey('notes'), isFalse);
      expect(_recoveredNotes(context), [
        {'unparsedRecoveryValue': 'prior malformed recovery'},
        {'id': 'invalid'},
      ]);
      expect(await repository.findById('current'), isNotNull);
      expect(await repository.findById('old'), isNull);
      preferences.reads.clear();

      await migrator.migrate();
      expect(preferences.reads, isEmpty);
      expect(_recoveredNotes(context), hasLength(2));
    },
  );
}

void _registerInterruptedPreferenceCleanupTest(
  _MigrationContext Function() contextFactory,
) {
  test(
    'retries failed preference removal without decoding or reimport',
    () async {
      final context = contextFactory();
      final note = _note('once');
      await _seedLegacyStorage(context, note);
      final preferences = _ReadTrackingPreferences(context.preferences);
      preferences.removeOverride = (key) async =>
          key == 'notes' ? false : context.preferences.remove(key);
      LegacyPreferencesMigrator openMigrator() =>
          context.migrator(preferences: preferences);

      expect(await openMigrator().migrate(), isTrue);
      expect(context.preferences.containsKey('notes'), isTrue);
      expect(context.preferences.containsKey('app_settings'), isFalse);
      final repository = NotesRepository(context.database);
      expect(await repository.findById(note.id), isNotNull);
      await repository.remove(note.id);
      preferences.reads.clear();
      final retryAttempts = <String>[];
      preferences.removeOverride = (key) async {
        retryAttempts.add(key);
        throw StateError('synthetic preference removal failure');
      };

      await openMigrator().migrate();
      expect(preferences.reads, isEmpty);
      expect(retryAttempts, ['notes']);
      expect(context.preferences.containsKey('notes'), isTrue);
      preferences.removeOverride = null;

      await openMigrator().migrate();
      expect(preferences.reads, isEmpty);
      expect(context.preferences.containsKey('notes'), isFalse);
      expect(context.preferences.containsKey('app_settings'), isFalse);
      expect(await repository.findById(note.id), isNull);
    },
  );
}

void _registerInterruptedCredentialCleanupTest(
  _MigrationContext Function() contextFactory,
) {
  test('defers obsolete secure-store cleanup and retries failures', () async {
    final context = contextFactory();
    const key = 'api_key_openrouter';
    const activeKey = 'api_key_google';
    await context.secureStorage.write(key: key, value: 'synthetic-obsolete');
    await context.secureStorage.write(
      key: activeKey,
      value: 'synthetic-active',
    );
    final storage = _FailingCredentialStore(context.secureStorage, key);
    LegacyPreferencesMigrator openMigrator() =>
        context.migrator(secureStorage: storage);

    final migrator = openMigrator();
    expect(await migrator.migrate(), isTrue);
    expect(storage.removals, isEmpty);
    await migrator.cleanupObsoleteCredentials();
    expect(await context.secureStorage.containsKey(key: key), isTrue);

    final reopened = openMigrator();
    expect(await reopened.migrate(), isTrue);
    await reopened.cleanupObsoleteCredentials();
    expect(await openMigrator().migrate(), isFalse);
    expect(await context.secureStorage.containsKey(key: key), isFalse);
    expect(await context.secureStorage.containsKey(key: activeKey), isTrue);
    storage.removals.clear();

    await openMigrator().cleanupObsoleteCredentials();
    expect(storage.removals, isEmpty);
  });
}

class _FailingCredentialStore extends Fake implements FlutterSecureStorage {
  _FailingCredentialStore(this.delegate, this.failOnceFor);

  final FlutterSecureStorage delegate;
  final String failOnceFor;
  final removals = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName != #delete) {
      return super.noSuchMethod(invocation);
    }
    final key = invocation.namedArguments[#key] as String;
    final fails = key == failOnceFor && !removals.contains(key);
    removals.add(key);
    return fails
        ? Future<void>.error(StateError('synthetic secure-store failure'))
        : delegate.delete(key: key);
  }
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

void _registerAtomicMigrationTest(_MigrationContext Function() contextFactory) {
  test(
    'imports settings and notes atomically and cleans legacy storage',
    () async {
      final context = contextFactory();
      final note = _note('legacy-note');
      await _seedLegacyStorage(context, note);
      await _migrate(context);
      await _expectAtomicMigration(context, note);
    },
  );
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

void _registerMalformedPayloadTest(
  _MigrationContext Function() contextFactory,
) {
  test('keeps malformed legacy payloads for recovery after import', () async {
    final context = contextFactory();
    await context.preferences.setString('app_settings', 'not-json');
    await context.preferences.setString('notes', jsonEncode({'not': 'a-list'}));

    await LegacyPreferencesMigrator(
      database: context.database,
      preferences: context.preferences,
      secureStorage: context.secureStorage,
    ).migrate();

    expect(context.preferences.getString('app_settings'), 'not-json');
    expect(
      context.preferences.getString('notes'),
      jsonEncode({'not': 'a-list'}),
    );
    expect(
      await context.database.select(context.database.notesTable).get(),
      isEmpty,
    );
  });
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
