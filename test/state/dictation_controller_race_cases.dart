part of 'dictation_controller_test.dart';

void _registerSessionRaceTests() {
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

Future<void> _replaceController(SettingsRepository settings) async {
  controller.dispose();
  controller = DictationController(
    settingsRepository: settings,
    platform: platform,
    clientFactory: (_) {
      final client = FakeLiveTranscriptionClient();
      clients.add(client);
      return client;
    },
  );
  await controller.initialize();
}

final class _GatedSettingsRepository extends SettingsRepository {
  _GatedSettingsRepository(super.database);

  int keyReads = 0;
  Completer<String?>? keyGate;

  @override
  Future<String?> apiKey(RemoteProviderId provider) async {
    keyReads++;
    final gate = keyGate;
    return gate == null ? 'synthetic-key' : gate.future;
  }
}
