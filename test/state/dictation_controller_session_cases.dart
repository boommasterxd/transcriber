part of 'dictation_controller_test.dart';

void _registerSessionLifecycleTests() {
  _registerCancelSessionTextTest();
  _registerStopFinalizedTextTest();
  _registerCompositionCoalescingTest();
  _registerSessionTranscriptLimitTest();
  _registerEditorRestorationTest();
  _registerCompositionDiscardTest();
  _registerCompositionSessionChangeTest();
}

void _registerCancelSessionTextTest() {
  test(
    'cancel removes partial and finalized session text without committing',
    () async {
      await controller.start();
      clients.single.controller.add(const LiveTranscriptionFinal('Alles'));
      clients.single.controller.add(
        const LiveTranscriptionPartial('verwerfen'),
      );
      await pumpEventQueue();

      await controller.cancel();

      expect(platform.compositions.last.text, 'Alles verwerfen');
      expect(platform.clears, ['editor-1']);
      expect(platform.commits, isEmpty);
      expect(controller.state.phase, DictationPhase.ready);
    },
  );
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

void _registerCompositionCoalescingTest() {
  test(
    'coalesces pending compositions and commits the latest final text',
    () async {
      final compositionGate = Completer<bool>();
      platform.compositionGate = compositionGate;
      await controller.start();

      clients.single.controller.add(
        const LiveTranscriptionPartial('Entwurf 0'),
      );
      await pumpEventQueue();
      for (var index = 1; index <= 50; index++) {
        clients.single.controller.add(
          LiveTranscriptionPartial('Entwurf $index'),
        );
      }
      clients.single.controller.add(
        const LiveTranscriptionFinal('Finaler Text.'),
      );
      await pumpEventQueue();
      expect(platform.compositions.map((entry) => entry.text), ['Entwurf 0']);

      final stopping = controller.stop();
      await pumpEventQueue();
      expect(clients.single.finished, isTrue);
      expect(platform.commits, isEmpty);

      compositionGate.complete(true);
      await stopping;
      expect(platform.compositions.map((entry) => entry.text), [
        'Entwurf 0',
        'Finaler Text.',
      ]);
      expect(platform.commits.single.text, 'Finaler Text.');
    },
  );
}

void _registerSessionTranscriptLimitTest() {
  test('rejects a session transcript above its character limit', () async {
    await controller.start();
    final oversizedText = List.filled(
      LiveTranscriptionLimits.maximumTranscriptCharacters + 1,
      'x',
    ).join();

    clients.single.controller.add(LiveTranscriptionFinal(oversizedText));
    await pumpEventQueue();

    expect(controller.state.phase, DictationPhase.error);
    expect(controller.state.errorCode, 'provider_rejected');
    expect(platform.compositions, isEmpty);
    expect(platform.commits, isEmpty);
    expect(platform.clears, ['editor-1']);
  });
}

void _registerEditorRestorationTest() {
  test(
    'restores the newest editor after slow hidden-session cleanup',
    () async {
      await controller.start();
      final closeGate = Completer<void>();
      clients.single.closeGate = closeGate;

      platform.changeEditor(
        const KeyboardEditorState(
          sessionId: 'hidden-editor',
          visible: false,
          supported: false,
          microphoneGranted: true,
        ),
      );
      await pumpEventQueue();
      platform.changeEditor(
        const KeyboardEditorState(
          sessionId: 'restored-editor',
          visible: true,
          supported: true,
          microphoneGranted: true,
        ),
      );
      await pumpEventQueue();

      closeGate.complete();
      await pumpEventQueue(times: 10);

      expect(controller.state.phase, DictationPhase.ready);
      expect(controller.state.visible, isTrue);
      expect(controller.state.editorSupported, isTrue);
      expect(clients.single.closed, isTrue);
    },
  );
}

void _registerCompositionDiscardTest() {
  test(
    'discard waits for an in-flight composition before clearing it',
    () async {
      final compositionGate = Completer<bool>();
      platform.compositionGate = compositionGate;
      await controller.start();
      clients.single.controller.add(const LiveTranscriptionPartial('Entwurf'));
      clients.single.controller.add(
        const LiveTranscriptionPartial('Ausstehender Entwurf'),
      );
      await pumpEventQueue();

      final discarding = controller.cancel();
      await pumpEventQueue();
      expect(platform.clears, isEmpty);

      compositionGate.complete(true);
      await discarding;

      expect(platform.compositions.single.text, 'Entwurf');
      expect(platform.clears, ['editor-1']);
      expect(platform.commits, isEmpty);
    },
  );
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
