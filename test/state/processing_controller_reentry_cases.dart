part of 'processing_controller_test.dart';

void _registerReplacementTests() {
  test(
    'new input waits for a discarded run without exposing its result',
    () async {
      final harness = await _Harness.create(summaryEnabled: false);
      addTearDown(harness.dispose);
      final gate = _pauseStage(harness, ProcessingStep.transcribing);
      final second = await _newInput(harness, 'second.m4a');
      final oldOwner = Object();
      final newOwner = Object();
      final results = <TranscriptNote>[];
      final subscription = harness.container.listen(
        processingControllerProvider,
        (_, state) {
          if (state.result != null) results.add(state.result!);
        },
      );
      addTearDown(subscription.close);

      final firstRun = harness.controller.run(
        _originalInput(harness),
        owner: oldOwner,
      );
      await gate.started.future;
      await harness.controller.discardCurrent(owner: oldOwner);
      final secondRun = harness.controller.run(second, owner: newOwner);
      await harness.controller.discardCurrent(owner: oldOwner);
      expect(harness.state.fileName, 'second.m4a');
      expect(harness.clientFactory.calls, hasLength(1));

      harness.clientFactory.beforeStage = null;
      gate.resume.complete();
      await Future.wait([firstRun, secondRun]);

      expect(harness.clientFactory.calls, hasLength(2));
      expect(results.map((note) => note.title), ['second.m4a']);
      expect((await harness.notesRepository.load()).single.title, 'second.m4a');
      expect(await harness.staging.exists(), isFalse);
      expect(await File(second.audioPath).exists(), isFalse);
      expect(harness.state.running, isFalse);
      expect(harness.state.error, isNull);
    },
  );
}

ProcessingInput _originalInput(_Harness harness) => ProcessingInput(
  audio: ManagedAudioFile(
    path: harness.staging.path,
    ownership: AudioOwnership.temporary,
  ),
  source: NoteSource.file,
  knownDurationSec: 1,
);

Future<ProcessingInput> _newInput(_Harness harness, String name) async {
  final file = File('${harness.staging.parent.path}/$name');
  await file.writeAsBytes([4, 5, 6]);
  return ProcessingInput(
    audio: ManagedAudioFile(
      path: file.path,
      ownership: AudioOwnership.temporary,
    ),
    source: NoteSource.file,
    knownDurationSec: 1,
  );
}
