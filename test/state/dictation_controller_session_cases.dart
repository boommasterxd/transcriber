part of 'dictation_controller_test.dart';

void _registerSessionLifecycleTests() {
  _registerStopFinalizedTextTest();
  _registerCompositionSessionChangeTest();
}

void _registerStopFinalizedTextTest() {
  test('stop commits all finalized segments as one transcript', () async {
    await controller.start();
    clients.single.controller.add(const LiveTranscriptionFinal('Erster Satz.'));
    clients.single.controller.add(
      const LiveTranscriptionFinal('Zweiter Satz.'),
    );
    await pumpEventQueue();

    await controller.stop();

    expect(platform.compositions.last.text, 'Erster Satz. Zweiter Satz.');
    expect(platform.commits.single.text, 'Erster Satz. Zweiter Satz.');
    expect(platform.clears, isEmpty);
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
