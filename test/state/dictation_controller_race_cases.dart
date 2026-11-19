part of 'dictation_controller_test.dart';

void _registerSessionRaceTests() {
  _registerConfigurationRaceTests();
  _registerCaptureRaceTests();
}

void _registerConfigurationRaceTests() {
  test(
    'reserves start before settings and discards a late settings read',
    () async {
      final settings = _GatedSettingsRepository(database);
      await _replaceController(settings);
      final gate = Completer<AppSettings>();
      settings.settingsGate = gate;

      final starting = controller.start();
      expect(controller.state.phase, DictationPhase.connecting);
      await controller.start();
      expect(settings.settingsReads, 2);
      await controller.cancel();
      settings.settingsGate = null;
      await controller.start();
      gate.complete(AppSettings.initial());
      await starting;

      expect(settings.keyReads, 1);
      expect(clients, hasLength(1));
      expect(platform.starts, hasLength(1));
      expect(controller.state.phase, DictationPhase.recording);
    },
  );

  test(
    'rejects a credential read completing after editor replacement',
    () async {
      final settings = _GatedSettingsRepository(database);
      await _replaceController(settings);
      final gate = Completer<String?>();
      settings.keyGate = gate;
      final starting = controller.start();
      await pumpEventQueue();
      expect(settings.keyReads, 1);

      platform.changeEditor(
        const KeyboardEditorState(
          sessionId: 'editor-2',
          visible: true,
          supported: true,
          microphoneGranted: true,
        ),
      );
      await pumpEventQueue();
      gate.complete('synthetic-key');
      await starting;

      expect(clients, isEmpty);
      expect(platform.starts, isEmpty);
      expect(controller.state.phase, DictationPhase.ready);
    },
  );
}

void _registerCaptureRaceTests() {
  test('waits for a pending microphone resume before a fresh start', () async {
    await controller.start();
    await controller.togglePause();
    final resumed = Completer<void>();
    platform.resumeGate = resumed;
    final resuming = controller.togglePause();
    final cancelling = controller.cancel();

    await controller.start();
    expect(platform.starts, hasLength(1));
    expect(clients.single.closed, isTrue);
    resumed.complete();
    await resuming;
    await cancelling;
    expect(controller.state.phase, DictationPhase.ready);

    await controller.start();
    expect(platform.starts, hasLength(2));
    expect(clients, hasLength(2));
    expect(controller.state.phase, DictationPhase.recording);
  });

  test('cancels reconnect backoff before a fresh microphone session', () async {
    const retryDelay = Duration(seconds: 2);
    final delayScheduled = Completer<_ManualTimer>();
    await runZoned(
      () async {
        final settings = _GatedSettingsRepository(database);
        await _replaceController(settings, retryDelay: retryDelay);
        await controller.start();
        await controller.togglePause();
        clients.single.controller.add(const LiveTranscriptionDisconnected());
        final delay = await delayScheduled.future;
        expect(controller.state.phase, DictationPhase.reconnecting);

        await controller.cancel();
        await controller.start();
        delay.elapse();
        await pumpEventQueue();

        expect(delay.isActive, isFalse);
        expect(clients, hasLength(2));
        expect(platform.starts, hasLength(2));
        expect(platform.resumeCount, 0);
        expect(controller.state.phase, DictationPhase.recording);
        await controller.cancel();
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (_, parent, zone, duration, callback) {
          if (duration != retryDelay) {
            return parent.createTimer(zone, duration, callback);
          }
          final timer = _ManualTimer(() => zone.runGuarded(callback));
          delayScheduled.complete(timer);
          return timer;
        },
      ),
    );
  });
}

Future<void> _replaceController(
  SettingsRepository settings, {
  Duration retryDelay = Duration.zero,
}) async {
  controller.dispose();
  controller = DictationController(
    settingsRepository: settings,
    platform: platform,
    clientFactory: (_) {
      final client = FakeLiveTranscriptionClient();
      clients.add(client);
      return client;
    },
    reconnectDelays: [retryDelay],
  );
  await controller.initialize();
}

final class _GatedSettingsRepository extends SettingsRepository {
  _GatedSettingsRepository(super.database);

  int settingsReads = 0;
  int keyReads = 0;
  Completer<AppSettings>? settingsGate;
  Completer<String?>? keyGate;

  @override
  Future<AppSettings> load() async {
    settingsReads++;
    final gate = settingsGate;
    return gate == null ? AppSettings.initial() : gate.future;
  }

  @override
  Future<String?> apiKey(RemoteProviderId provider) async {
    keyReads++;
    final gate = keyGate;
    return gate == null ? 'synthetic-key' : gate.future;
  }
}

final class _ManualTimer implements Timer {
  _ManualTimer(this.callback);
  final void Function() callback;

  @override
  bool isActive = true;
  @override
  int tick = 0;

  @override
  void cancel() => isActive = false;

  void elapse() {
    if (!isActive) return;
    isActive = false;
    tick++;
    callback();
  }
}
