import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/repositories/settings_repository.dart';
import 'package:transcriber/services/audio/audio_recorder_service.dart';
import 'package:transcriber/services/remote/remote_audio_limits.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/recording_controller.dart';
import 'package:transcriber/state/settings_controller.dart';

import '../support/app_test_fakes.dart' show TestSettingsController;
import 'state_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = _RecordingFixture();
  setUp(fixture.setUp);
  tearDown(fixture.tearDown);
  _registerStartTests(fixture);
  _registerLimitTests(fixture);
}

void _registerLimitTests(_RecordingFixture fixture) {
  test('resolves the persisted model budget before capture', () async {
    fixture.container.dispose();
    await SettingsRepository(fixture.database).save(
      const AppSettings(
        transcription: TranscriptionSettings(
          provider: RemoteProviderId.openai,
          models: {RemoteProviderId.openai: 'gpt-transcribe'},
        ),
      ),
    );
    fixture.container = ProviderContainer(
      overrides: [
        audioRecorderProvider.overrideWithValue(fixture.recorder),
        databaseProvider.overrideWithValue(fixture.database),
        initialSettingsProvider.overrideWithValue(const AppSettings()),
      ],
    );
    await fixture.controller.start();
    expect(fixture.recorder.recordingMaxBytes, maxOpenAiTranscriptionBytes);
    expect(fixture.state.boundary.maxDurationSec, 781);
    await fixture.controller.start();
    expect(fixture.recorder.startCalls, 1);
  });

  testWidgets('native byte completion preserves audio and cannot resume', (
    tester,
  ) async {
    await fixture.controller.start();
    fixture.recorder.progress.add(
      const RecordingProgress(
        dataBytes: 32000 * 3276,
        stopped: true,
        limited: true,
      ),
    );
    expect(fixture.state.active, isFalse);
    expect(fixture.state.boundary.reached, isTrue);
    expect(fixture.state.elapsedSec, 3276);
    expect(fixture.state.path, fixture.recorder.path);
    await fixture.controller.togglePause();
    expect(fixture.recorder.resumeCalls, 0);
    await tester.pump(const Duration(minutes: 10));
    expect(fixture.state.elapsedSec, 3276);
    expect((await fixture.controller.stop())?.durationSec, 3276);
  });
}

void _registerStartTests(_RecordingFixture fixture) {
  test('refuses to start without microphone permission', () async {
    fixture.recorder.permission = false;

    expect(await fixture.controller.start(), isFalse);
    expect(fixture.recorder.startCalls, 0);
    expect(fixture.state.active, isFalse);
  });

  test('cancel during native startup tears down late capture', () async {
    fixture.recorder.startRequest = Completer<String>();
    final starting = fixture.controller.start();
    await fixture.recorder.started.future;
    await fixture.controller.cancel();
    fixture.recorder.startRequest!.complete(fixture.recorder.path);
    expect(await starting, isFalse);
    expect(fixture.recorder.cancelCalls, 2);
    expect(fixture.state.active, isFalse);
  });
}

class _RecordingFixture {
  late Directory root;
  late AppDatabase database;
  late ProviderContainer container;
  late _StartedRecorder recorder;

  Future<void> setUp() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
    root = await Directory.systemTemp.createTemp('recording_controller_test_');
    final paths = StoragePaths(
      supportRoot: Directory('${root.path}/support'),
      cacheRoot: Directory('${root.path}/cache'),
    );
    database = createTestDatabase();
    recorder = _StartedRecorder(AudioCacheManager(paths: Future.value(paths)));
    container = ProviderContainer(
      overrides: [
        audioRecorderProvider.overrideWithValue(recorder),
        settingsControllerProvider.overrideWith(TestSettingsController.new),
      ],
    );
  }

  RecordingController get controller =>
      container.read(recordingControllerProvider.notifier);
  RecordingState get state => container.read(recordingControllerProvider);

  Future<void> tearDown() async {
    container.dispose();
    await database.close();
    await recorder.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          null,
        );
    await root.delete(recursive: true);
  }
}

final class _StartedRecorder extends FakeAudioRecorderService {
  _StartedRecorder(super.cacheManager);

  final started = Completer<void>();

  @override
  Future<String> start({int? maxBytes}) {
    final result = maxBytes == null
        ? super.start()
        : super.start(maxBytes: maxBytes);
    if (!started.isCompleted) started.complete();
    return result;
  }
}
