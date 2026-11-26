import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_accent.dart';
import 'package:transcriber/data/models/app_language.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcription_language.dart';
import 'package:transcriber/data/repositories/settings_repository.dart';

void main() {
  late AppDatabase database;
  late FlutterSecureStorage secureStorage;
  late SettingsRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    secureStorage = const FlutterSecureStorage();
    FlutterSecureStorage.setMockInitialValues({});
    repository = SettingsRepository(database, secureStorage: secureStorage);
  });

  tearDown(() => database.close());

  test('round-trips settings without storing keys in the database', () async {
    final settings = AppSettings.initial().copyWith(
      appearance: const AppearanceSettings(
        themeMode: AppThemeMode.dark,
        accent: AppAccent.magenta,
        language: AppLanguage.en,
      ),
      transcription: const TranscriptionSettings(
        language: TranscriptionLanguage.de,
        provider: RemoteProviderId.openai,
        models: {RemoteProviderId.openai: 'gpt-transcribe'},
      ),
      summary: const SummarySettings(
        provider: RemoteProviderId.google,
        models: {RemoteProviderId.google: 'gemini-summary'},
      ),
      onboarded: true,
    );

    await repository.save(settings);
    final loaded = await repository.load();

    expect(loaded.toJson(), settings.toJson());
    await repository.setApiKey(RemoteProviderId.openai, 'private-key');
    final row = await database.select(database.appSettingsTable).getSingle();
    expect(row.themeMode, 'dark');
    expect(row.accent, 'magenta');
    expect(row.language, 'en');
    expect(row.transcriptionLanguage, 'de');
    expect(row.asrProvider, 'openai');
    expect(row.asrModel, 'gpt-transcribe');
    expect(await secureStorage.read(key: 'api_key_openai'), 'private-key');
  });
}
