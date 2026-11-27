import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart'
    show
        ApplyInterceptorConnection,
        DatabaseConnection,
        QueryExecutor,
        QueryExecutorUser,
        QueryInterceptor,
        TransactionExecutor;
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
  test(
    'independent connections merge settings and keep keys separate',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'settings-repository-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/settings.sqlite');
      final database = AppDatabase(_backgroundConnection(file));
      addTearDown(database.close);
      const secureStorage = FlutterSecureStorage();
      FlutterSecureStorage.setMockInitialValues({});
      final repository = SettingsRepository(
        database,
        secureStorage: secureStorage,
      );
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

      await _verifyConcurrentUpdates(file, database, repository);
    },
  );
}

DatabaseConnection _backgroundConnection(File file) =>
    NativeDatabase.createBackgroundConnection(
      file,
      setup: (database) => database.execute(
        'PRAGMA busy_timeout = ${AppDatabase.sqliteBusyTimeoutMs}',
      ),
    );

Future<void> _verifyConcurrentUpdates(
  File file,
  AppDatabase database,
  SettingsRepository repository,
) async {
  final observer = _CompetingTransaction();
  final otherDatabase = AppDatabase(
    _backgroundConnection(file).interceptWith(observer),
  );
  addTearDown(otherDatabase.close);
  await otherDatabase.customSelect('SELECT 1').getSingle();
  final otherEngine = SettingsRepository(otherDatabase);
  final writerReady = Completer<void>();
  final first = database.transaction(() async {
    await repository.update(
      (current) => current.copyWith(autoDeleteAudio: true),
    );
    writerReady.complete();
    await observer.started.future;
  });
  final second = _updateWhileWriterIsActive(
    first,
    writerReady,
    otherEngine,
    observer,
  );
  await Future.wait([first, second]);

  final merged = await repository.load();
  expect(merged.autoDeleteAudio, isTrue);
  expect(merged.summarizeEnabled, isFalse);
  expect(merged.asrProvider, RemoteProviderId.openai);
  expect(merged.asrModelId(merged.asrProvider), 'gpt-transcribe');
  expect(merged.summaryModelId(merged.summaryProvider), 'gemini-summary');
}

Future<void> _updateWhileWriterIsActive(
  Future<void> first,
  Completer<void> writerReady,
  SettingsRepository repository,
  _CompetingTransaction observer,
) async {
  await Future.any([first, writerReady.future]);
  try {
    await repository.update((current) {
      expect(current.autoDeleteAudio, isTrue);
      return current.copyWith(
        summary: current.summary.copyWith(enabled: false),
      );
    });
  } finally {
    observer.release();
  }
}

/// Lets the first writer commit after the second connection requests its lock.
final class _CompetingTransaction extends QueryInterceptor {
  final started = Completer<void>();

  void release() {
    if (!started.isCompleted) started.complete();
  }

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) {
    final opening = super.ensureOpen(executor, user);
    // BEGIN IMMEDIATE must finish before any SQL in the callback can run.
    if (executor is TransactionExecutor) release();
    return opening;
  }
}
