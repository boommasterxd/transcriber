import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcription_language.dart';
import 'package:transcriber/data/repositories/settings_repository.dart';
import 'package:transcriber/services/dictation/dictation_platform.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';
import 'package:transcriber/state/dictation_controller.dart';
import 'package:transcriber/state/dictation_state.dart';

import 'dictation_test_support.dart';

part 'dictation_controller_session_cases.dart';
part 'dictation_controller_race_cases.dart';

late AppDatabase database;
late SettingsRepository repository;
late FakeDictationPlatform platform;
late List<FakeLiveTranscriptionClient> clients;
late DictationController controller;

void main() {
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({'api_key_openai': 'test-key'});
    repository = SettingsRepository(database);
    await repository.save(
      AppSettings.initial().copyWith(
        transcription: const TranscriptionSettings(
          provider: RemoteProviderId.openai,
          language: TranscriptionLanguage.de,
        ),
      ),
    );
    platform = FakeDictationPlatform();
    clients = [];
    controller = DictationController(
      settingsRepository: repository,
      platform: platform,
      clientFactory: (_) {
        final client = FakeLiveTranscriptionClient();
        clients.add(client);
        return client;
      },
      reconnectDelays: const [Duration.zero, Duration.zero],
    );
    await controller.initialize();
  });

  tearDown(() async {
    controller.dispose();
    for (final client in clients) {
      if (!client.controller.isClosed) await client.controller.close();
    }
    await platform.close();
    await database.close();
  });

  _registerStartupAndEditingTests();
  _registerSessionLifecycleTests();
  _registerPauseTests();
  _registerSafetyTests();
  _registerSessionRaceTests();
}

void _registerStartupAndEditingTests() {
  test(
    'streams audio and composes recognized text before committing',
    () async {
      await controller.start();
      platform.emitAudio([1, 2, 3], level: 0.7);
      clients.single.controller.add(const LiveTranscriptionPartial('Hal'));
      await pumpEventQueue();

      expect(clients.single.audio.single, [1, 2, 3]);
      expect(controller.state.phase, DictationPhase.correcting);
      expect(platform.compositions.single.text, 'Hal');

      clients.single.controller.add(const LiveTranscriptionFinal('Hallo'));
      await pumpEventQueue();
      expect(platform.compositions.last.text, 'Hallo');
      expect(platform.commits, isEmpty);
      expect(controller.state.phase, DictationPhase.recording);
      expect(controller.state.preview, 'Hallo');
    },
  );
}

void _registerPauseTests() {
  test('pauses capture and resumes the same live session', () async {
    await controller.start();
    platform.emitAudio([1, 2], level: 0.6);
    await pumpEventQueue();

    await controller.togglePause();
    platform.emitAudio([3, 4], level: 0.9);
    clients.single.controller.add(
      const LiveTranscriptionPartial('Zwischenstand'),
    );
    await pumpEventQueue();

    expect(controller.state.phase, DictationPhase.paused);
    expect(controller.state.preview, 'Zwischenstand');
    expect(platform.pauseCount, 1);
    expect(clients.single.audio, [
      [1, 2],
    ]);
    expect(clients.single.closed, isFalse);

    await controller.togglePause();

    expect(controller.state.phase, DictationPhase.recording);
    expect(platform.resumeCount, 1);
    expect(clients, hasLength(1));
  });
}

void _registerSafetyTests() {
  test(
    'rejects missing permission and missing credentials before capture',
    () async {
      platform.changeEditor(
        const KeyboardEditorState(
          sessionId: 'editor-2',
          visible: true,
          supported: true,
          microphoneGranted: false,
        ),
      );
      await pumpEventQueue();
      await controller.start();
      expect(controller.state.errorCode, 'microphone_denied');
      expect(platform.starts, isEmpty);

      platform.changeEditor(
        const KeyboardEditorState(
          sessionId: 'editor-3',
          visible: true,
          supported: true,
          microphoneGranted: true,
        ),
      );
      FlutterSecureStorage.setMockInitialValues({});
      await pumpEventQueue();
      await controller.start();
      expect(controller.state.errorCode, 'api_key_missing');
      expect(platform.starts, isEmpty);
    },
  );
}
