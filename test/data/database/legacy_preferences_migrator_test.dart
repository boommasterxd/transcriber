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
  id: id,
  title: 'Legacy title',
  speaker: 'Legacy speaker',
  source: NoteSource.file,
  durationSec: 12,
  createdAt: DateTime.utc(2025, 1, 1),
  asrIsLocal: true,
  summaryIsLocal: false,
  asrName: 'Whisper Base',
  asrSub: 'Local',
  llmName: 'Gemma',
  llmSub: 'Local',
  gist: 'Legacy gist',
  points: const ['Legacy point'],
  todos: [TodoItem(text: 'Legacy todo')],
  transcript: const [TranscriptLine(time: '00:01', text: 'Legacy transcript')],
  audioPath: '/external/legacy.m4a',
);
