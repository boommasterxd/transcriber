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

late AppDatabase database;
late SettingsRepository repository;
late FakeDictationPlatform platform;
late List<FakeLiveTranscriptionClient> clients;
late DictationController controller;
Completer<void>? nextConnectGate;
Object? nextConnectError;
bool controllerDisposed = false;

void main() {
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    FlutterSecureStorage.setMockInitialValues({'api_key_openai': 'test-key'});
    repository = SettingsRepository(database);
    await repository.save(
      AppSettings.initial().copyWith(
        asrProvider: RemoteProviderId.openai,
        transcriptionLanguage: TranscriptionLanguage.de,
      ),
    );
    platform = FakeDictationPlatform();
    clients = [];
    nextConnectGate = null;
    nextConnectError = null;
    controllerDisposed = false;
    controller = DictationController(
      settingsRepository: repository,
      platform: platform,
      clientFactory: (_) {
        final client = FakeLiveTranscriptionClient();
        client.connectGate = nextConnectGate;
        client.connectError = nextConnectError;
        nextConnectGate = null;
        clients.add(client);
        return client;
      },
      reconnectDelays: const [Duration.zero, Duration.zero],
    );
    await controller.initialize();
  });

  tearDown(() async {
    if (!controllerDisposed) controller.dispose();
    for (final client in clients) {
      if (!client.controller.isClosed) await client.controller.close();
    }
    await platform.close();
    await database.close();
  });

  _registerStartupAndEditingTests();
  _registerSafetyTests();
  _registerRecoveryTests();
  _registerResourceLifecycleTests();
}

void _registerStartupAndEditingTests() {
  test(
    'loads the live model and starts provider-specific PCM capture',
    () async {
      expect(controller.state.phase, DictationPhase.ready);
      expect(controller.state.modelId, 'gpt-live-transcribe');

      await controller.start();

      expect(controller.state.phase, DictationPhase.recording);
      expect(platform.starts.single.sessionId, 'editor-1');
      expect(platform.starts.single.sampleRate, 24000);
      expect(clients.single.connected, isTrue);
    },
  );

  test(
    'streams audio, composes partials, and commits finalized text',
    () async {
      await controller.start();
      platform.emitAudio([1, 2, 3], level: 0.7);
      clients.single.controller.add(const LiveTranscriptionPartial('Hal'));
      await pumpEventQueue();

      expect(clients.single.audio.single, [1, 2, 3]);
      expect(controller.state.levels, [0.7]);
      expect(controller.state.phase, DictationPhase.correcting);
      expect(platform.compositions.single.text, 'Hal');

      clients.single.controller.add(const LiveTranscriptionFinal('Hallo'));
      await pumpEventQueue();
      expect(platform.commits.single.text, 'Hallo');
      expect(controller.state.phase, DictationPhase.recording);
      expect(controller.state.preview, isEmpty);
    },
  );

  test(
    'finalizes the current partial on stop and releases resources',
    () async {
      await controller.start();
      clients.single.controller.add(
        const LiveTranscriptionPartial('Letzter Teil'),
      );
      await pumpEventQueue();

      await controller.stop();

      expect(platform.stopCount, 1);
      expect(platform.commits.last.text, 'Letzter Teil');
      expect(clients.single.finished, isTrue);
      expect(clients.single.closed, isTrue);
      expect(controller.state.phase, DictationPhase.ready);
    },
  );

  test(
    'uses the provider final instead of duplicating the partial on stop',
    () async {
      await controller.start();
      clients.single.controller.add(
        const LiveTranscriptionPartial('Unvollständig'),
      );
      clients.single.finalTextOnFinish = 'Vollständig';

      await controller.stop();

      expect(platform.commits.map((entry) => entry.text), ['Vollständig']);
    },
  );

  test('cancel removes composing text without committing it', () async {
    await controller.start();
    clients.single.controller.add(const LiveTranscriptionPartial('Verwerfen'));
    await pumpEventQueue();

    await controller.cancel();

    expect(platform.clears, ['editor-1']);
    expect(platform.commits, isEmpty);
    expect(controller.state.phase, DictationPhase.ready);
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

  test(
    'field changes invalidate active work and late text is ignored',
    () async {
      await controller.start();
      final staleClient = clients.single;
      platform.changeEditor(
        const KeyboardEditorState(
          sessionId: 'editor-2',
          visible: true,
          supported: true,
          microphoneGranted: true,
        ),
      );
      await pumpEventQueue();
      staleClient.controller.add(const LiveTranscriptionFinal('Zu spät'));
      await pumpEventQueue();

      expect(staleClient.closed, isTrue);
      expect(platform.commits, isEmpty);
      expect(controller.state.phase, DictationPhase.ready);
    },
  );

  test('hiding the current editor closes an active session', () async {
    await controller.start();
    final activeClient = clients.single;

    platform.changeEditor(
      const KeyboardEditorState(
        sessionId: 'editor-1',
        visible: false,
        supported: true,
        microphoneGranted: true,
      ),
    );
    await pumpEventQueue();

    expect(activeClient.closed, isTrue);
    expect(platform.stopCount, 1);
    expect(controller.state.phase, DictationPhase.unavailable);
  });
}

void _registerRecoveryTests() {
  test('buffers bounded audio during reconnect and replays it', () async {
    await controller.start();
    clients.single.controller.add(const LiveTranscriptionDisconnected());
    await pumpEventQueue();
    platform.emitAudio([9, 8]);
    await pumpEventQueue();

    expect(clients, hasLength(2));
    expect(clients.last.audio, [
      [9, 8],
    ]);
    expect(controller.state.phase, DictationPhase.recording);
  });

  test('provider and platform failures enter a safe error state', () async {
    await controller.start();
    clients.single.controller.add(const LiveTranscriptionFailure('quota'));
    await pumpEventQueue();

    expect(controller.state.phase, DictationPhase.error);
    expect(controller.state.errorCode, 'quota');
    expect(platform.clears, contains('editor-1'));
  });

  test('platform audio failures enter the same safe error state', () async {
    await controller.start();

    platform.emitFailure('audio_read_failed');
    await pumpEventQueue();

    expect(controller.state.phase, DictationPhase.error);
    expect(controller.state.errorCode, 'audio_read_failed');
    expect(clients.single.closed, isTrue);
  });

  test('switching back cancels dictation before changing the IME', () async {
    await controller.start();
    await controller.switchBack();

    expect(platform.switchCount, 1);
    expect(clients.single.closed, isTrue);
    expect(controller.state.phase, DictationPhase.ready);
  });
}

void _registerResourceLifecycleTests() {
  test('keeps only the newest bounded audio while reconnecting', () async {
    await controller.start();
    final gate = Completer<void>();
    nextConnectGate = gate;
    clients.single.controller.add(const LiveTranscriptionDisconnected());
    await pumpEventQueue();

    for (
      var value = 0;
      value < DictationController.maximumPendingChunks + 4;
      value++
    ) {
      platform.emitAudio([value]);
    }
    await pumpEventQueue();
    gate.complete();
    await pumpEventQueue();

    expect(
      clients.last.audio,
      hasLength(DictationController.maximumPendingChunks),
    );
    expect(clients.last.audio.first, [4]);
    expect(clients.last.audio.last, [15]);
  });

  test(
    'stops retrying and releases resources after reconnect exhaustion',
    () async {
      await controller.start();
      nextConnectError = StateError('offline');

      clients.single.controller.add(const LiveTranscriptionDisconnected());
      await pumpEventQueue(times: 40);

      expect(controller.state.phase, DictationPhase.error);
      expect(controller.state.errorCode, 'reconnect_failed');
      expect(platform.stopCount, 1);
      expect(clients.every((client) => client.closed), isTrue);
    },
  );

  test(
    'dispose rejects late provider text and releases active resources',
    () async {
      await controller.start();
      final activeClient = clients.single;

      controller.dispose();
      controllerDisposed = true;
      activeClient.controller.add(const LiveTranscriptionFinal('Zu spät'));
      await pumpEventQueue();

      expect(platform.commits, isEmpty);
      expect(platform.stopCount, 1);
      expect(activeClient.closed, isTrue);
    },
  );
}
