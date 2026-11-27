part of 'dictation_controller_test.dart';

void _registerSessionLifecycleTests() {
  _registerAutomaticFinalizationTest();
  _registerCompositionSessionChangeTest();
}

void _registerAutomaticFinalizationTest() {
  test('pause expiry commits staged segments to the active editor', () async {
    await controller.start();
    clients.single.controller.add(const LiveTranscriptionFinal('Erster Satz.'));
    clients.single.controller.add(
      const LiveTranscriptionFinal('Zweiter Satz.'),
    );
    clients.single.controller.add(const LiveTranscriptionPartial('Rest'));
    await pumpEventQueue();

    // Advancing only this timer keeps editor I/O and finalization in one zone.
    await runZoned(
      controller.togglePause,
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) =>
            parent.createTimer(
              zone,
              duration == LiveTranscriptionLimits.maximumIdleDuration
                  ? Duration.zero
                  : duration,
              callback,
            ),
      ),
    );
    expect(platform.commits, isEmpty);
    await pumpEventQueue();

    const transcript = 'Erster Satz. Zweiter Satz. Rest';
    expect(platform.compositions.last.text, transcript);
    expect(platform.commits.single, (sessionId: 'editor-1', text: transcript));
    expect(platform.clears, isEmpty);
    expect(controller.state.phase, DictationPhase.ready);
  });
}

void _registerCompositionSessionChangeTest() {
  test('drops pending old text before composing in the next editor', () async {
    final compositionGate = Completer<bool>();
    platform.compositionGate = compositionGate;
    await controller.start();
    clients.single.controller.add(const LiveTranscriptionPartial('Alter Text'));
    clients.single.controller.add(
      const LiveTranscriptionPartial('Veralteter Entwurf'),
    );

    platform.changeEditor(
      const KeyboardEditorState(
        sessionId: 'editor-2',
        visible: true,
        supported: true,
        microphoneGranted: true,
      ),
    );
    await pumpEventQueue();
    expect(platform.clears, isEmpty);

    compositionGate.complete(true);
    await pumpEventQueue();
    expect(platform.compositions.map((entry) => entry.text), ['Alter Text']);
    expect(platform.clears, ['editor-1']);
    expect(controller.state.phase, DictationPhase.ready);

    await controller.start();
    clients.last.controller.add(const LiveTranscriptionPartial('Neuer Text'));
    await controller.stop();

    expect(platform.compositions.last.sessionId, 'editor-2');
    expect(platform.compositions.last.text, 'Neuer Text');
    expect(platform.commits.single, (
      sessionId: 'editor-2',
      text: 'Neuer Text',
    ));
  });
}
