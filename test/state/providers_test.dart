import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _registerBootstrapTests();
  _registerRepositoryTest();
  _registerServiceTest();
}

void _registerBootstrapTests() {
  test('required bootstrap providers fail without explicit overrides', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => container.read(databaseProvider), _missingOverride);
    expect(() => container.read(initialSettingsProvider), _missingOverride);
    expect(() => container.read(initialConnectionsProvider), _missingOverride);
    expect(() => container.read(initialNotesProvider), _missingOverride);
  });

  test('bootstrap providers preserve all resolved values', () {
    final database = AppDatabase(NativeDatabase.memory());
    final settings = AppSettings.initial();
    const connections = {RemoteProviderId.google: true};
    const notes = <TranscriptNote>[];
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        initialSettingsProvider.overrideWithValue(settings),
        initialConnectionsProvider.overrideWithValue(connections),
        initialNotesProvider.overrideWithValue(notes),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    expect(container.read(databaseProvider), same(database));
    expect(container.read(initialSettingsProvider), same(settings));
    expect(container.read(initialConnectionsProvider), same(connections));
    expect(container.read(initialNotesProvider), same(notes));
  });
}

void _registerRepositoryTest() {
  test('repository providers share the overridden Drift database', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await container.read(notesRepositoryProvider).saveAll(const []);
    await container
        .read(settingsRepositoryProvider)
        .save(AppSettings.initial());

    expect(await database.select(database.notesTable).get(), isEmpty);
    expect(
      await database.select(database.appSettingsTable).get(),
      hasLength(1),
    );
    expect(
      container.read(settingsRepositoryProvider),
      same(container.read(settingsRepositoryProvider)),
    );
  });
}

void _registerServiceTest() {
  test('simple service providers cache values until disposal', () async {
    final recorderCalls = <MethodCall>[];
    final recorderDisposed = Completer<void>();
    const recorderChannel = MethodChannel('com.llfbandit.record/messages');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recorderChannel, (call) async {
          recorderCalls.add(call);
          if (call.method == 'dispose') recorderDisposed.complete();
          return null;
        });
    final container = ProviderContainer();
    final firstCacheManager = container.read(audioCacheManagerProvider);
    final firstPipeline = container.read(processingPipelineProvider);
    final firstRecorder = container.read(audioRecorderProvider);
    final firstShareService = container.read(shareIntentServiceProvider);

    expect(firstCacheManager, isA<AudioCacheManager>());
    expect(container.read(audioCacheManagerProvider), same(firstCacheManager));
    expect(container.read(processingPipelineProvider), same(firstPipeline));
    expect(container.read(audioRecorderProvider), same(firstRecorder));
    expect(container.read(shareIntentServiceProvider), same(firstShareService));

    container.dispose();
    await recorderDisposed.future;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recorderChannel, null);

    expect(recorderCalls.map((call) => call.method), contains('dispose'));
  });
}

final _missingOverride = throwsA(
  predicate<Object>((error) => error.toString().contains('must be overridden')),
);
