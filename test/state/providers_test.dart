import 'dart:async';
import 'dart:io';

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
    final harness = await _ServiceHarness.create();
    addTearDown(harness.close);
    final container = harness.container;
    final firstCacheManager = container.read(audioCacheManagerProvider);
    final firstPipeline = container.read(processingPipelineProvider);
    final firstRecorder = container.read(audioRecorderProvider);
    harness.recorderCreated = true;
    final firstShareService = container.read(shareIntentServiceProvider);

    expect(firstCacheManager, isA<AudioCacheManager>());
    expect(container.read(audioCacheManagerProvider), same(firstCacheManager));
    expect(container.read(processingPipelineProvider), same(firstPipeline));
    expect(container.read(audioRecorderProvider), same(firstRecorder));
    expect(container.read(shareIntentServiceProvider), same(firstShareService));

    await harness.finishStorageInitialization();
    harness.disposeContainer();
    await harness.waitForDisposal();

    expect(
      harness.recorderCalls.map((call) => call.method),
      contains('dispose'),
    );
  });
}

class _ServiceHarness {
  _ServiceHarness(this.root, this.messenger);

  static const _recorderChannel = MethodChannel(
    'com.llfbandit.record/messages',
  );
  static const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final Directory root;
  final TestDefaultBinaryMessenger messenger;
  final container = ProviderContainer();
  final recorderCalls = <MethodCall>[];
  final _recorderDisposed = Completer<void>();
  final _supportRequested = Completer<void>();
  final _supportResponse = Completer<String>();
  final _cacheRequested = Completer<void>();
  var recorderCreated = false;
  var _containerDisposed = false;

  static Future<_ServiceHarness> create() async {
    final harness = _ServiceHarness(
      await Directory.systemTemp.createTemp('provider-services-'),
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
    );
    harness.messenger.setMockMethodCallHandler(_recorderChannel, (call) async {
      harness.recorderCalls.add(call);
      if (call.method == 'dispose') harness._recorderDisposed.complete();
      return null;
    });
    harness.messenger.setMockMethodCallHandler(_pathChannel, harness._pathCall);
    return harness;
  }

  Future<Object?> _pathCall(MethodCall call) async {
    switch (call.method) {
      case 'getApplicationSupportDirectory':
        _supportRequested.complete();
        return _supportResponse.future;
      case 'getTemporaryDirectory':
        _cacheRequested.complete();
        return '${root.path}/cache';
      default:
        throw StateError('Unexpected storage method: ${call.method}');
    }
  }

  Future<void> finishStorageInitialization() async {
    await _supportRequested.future;
    expect(_supportResponse.isCompleted, isFalse);
    expect(messenger.pendingMessageCount, greaterThan(0));
    _supportResponse.complete('${root.path}/support');
    await _cacheRequested.future;
  }

  void disposeContainer() {
    if (_containerDisposed) return;
    container.dispose();
    _containerDisposed = true;
  }

  Future<void> waitForDisposal() async {
    await _recorderDisposed.future;
    await messenger.platformMessagesFinished;
    expect(messenger.pendingMessageCount, 0);
  }

  Future<void> close() async {
    try {
      if (!_supportResponse.isCompleted) {
        _supportResponse.complete('${root.path}/support');
      }
      if (_supportRequested.isCompleted) await _cacheRequested.future;
      disposeContainer();
      if (recorderCreated) await _recorderDisposed.future;
      await messenger.platformMessagesFinished;
    } finally {
      messenger.setMockMethodCallHandler(_recorderChannel, null);
      messenger.setMockMethodCallHandler(_pathChannel, null);
      await root.delete(recursive: true);
    }
  }
}

final _missingOverride = throwsA(
  predicate<Object>((error) => error.toString().contains('must be overridden')),
);
