import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/database/legacy_preferences_migrator.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/transcript_note.dart';

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
}

void _registerMigrationTests(_MigrationContext Function() contextFactory) {
  _registerAtomicMigrationTest(contextFactory);
  _registerIdempotentMigrationTest(contextFactory);
  _registerMalformedPayloadTest(contextFactory);
  _registerCompletedMigrationTest(contextFactory);
  _registerPartialMigrationTest(contextFactory);
  _registerFailedMigrationTest(contextFactory);
}

void _registerCompletedMigrationTest(
  _MigrationContext Function() contextFactory,
) {
  test(
    'completed migration skips retained payload reads and cleans secrets',
    () async {
      final context = contextFactory();
      await _migrate(context);
      await context.preferences.setString('app_settings', 'not-json');
      await context.preferences.setString('notes', 'recovery-data');
      await context.secureStorage.write(key: 'hf_token', value: 'legacy-token');
      await context.secureStorage.write(
        key: 'api_key_openrouter',
        value: 'obsolete-key',
      );
      final preferences = _ReadTrackingPreferences(context.preferences);

      await LegacyPreferencesMigrator(
        database: context.database,
        preferences: preferences,
        secureStorage: context.secureStorage,
      ).migrate();

      expect(preferences.reads, isEmpty);
      expect(context.preferences.getString('app_settings'), 'not-json');
      expect(context.preferences.getString('notes'), 'recovery-data');
      expect(await context.secureStorage.read(key: 'hf_token'), isNull);
      expect(
        await context.secureStorage.read(key: 'api_key_openrouter'),
        isNull,
      );
    },
  );
}

void _registerPartialMigrationTest(
  _MigrationContext Function() contextFactory,
) {
  test(
    'imports valid notes once and preserves partial-error recovery JSON',
    () async {
      final context = contextFactory();
      final note = _note('valid');
      final raw = jsonEncode([
        note.toJson(),
        {'id': 'invalid'},
      ]);
      await context.preferences.setString('notes', raw);
      final preferences = _ReadTrackingPreferences(context.preferences);
      final migrator = LegacyPreferencesMigrator(
        database: context.database,
        preferences: preferences,
        secureStorage: context.secureStorage,
      );

      await migrator.migrate();
      expect(preferences.reads, ['app_settings', 'notes']);
      final imported = await context.database
          .select(context.database.notesTable)
          .get();
      expect(imported.single.id, note.id);
      expect(context.preferences.getString('notes'), raw);
      preferences.reads.clear();

      await migrator.migrate();
      expect(preferences.reads, isEmpty);
      expect(context.preferences.getString('notes'), raw);
      expect(
        await context.database.select(context.database.notesTable).get(),
        hasLength(1),
      );
    },
  );
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

  @override
  String? getString(String key) {
    reads.add(key);
    return delegate.getString(key);
  }

  @override
  Future<bool> remove(String key) => delegate.remove(key);

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

Future<void> _migrate(_MigrationContext context) => LegacyPreferencesMigrator(
  database: context.database,
  preferences: context.preferences,
  secureStorage: context.secureStorage,
).migrate();

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
  expect(migrationState.single.key, LegacyPreferencesMigrator.marker);
}

void _registerIdempotentMigrationTest(
  _MigrationContext Function() contextFactory,
) {
  test('is idempotent and does not duplicate imported notes', () async {
    final context = contextFactory();
    final note = _note('once');
    await context.preferences.setString('notes', jsonEncode([note.toJson()]));
    final migrator = LegacyPreferencesMigrator(
      database: context.database,
      preferences: context.preferences,
      secureStorage: context.secureStorage,
    );

    await migrator.migrate();
    await migrator.migrate();

    expect(
      await context.database.select(context.database.notesTable).get(),
      hasLength(1),
    );
    expect(
      await context.database.select(context.database.migrationStateTable).get(),
      hasLength(1),
    );
  });
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
