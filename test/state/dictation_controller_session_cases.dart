part of 'dictation_controller_test.dart';

void _registerSessionLifecycleTests() {
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

  test(
    'discard waits for an in-flight composition before clearing it',
    () async {
      final compositionGate = Completer<bool>();
      platform.compositionGate = compositionGate;
      await controller.start();
      clients.single.controller.add(const LiveTranscriptionPartial('Entwurf'));
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
