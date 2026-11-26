part of 'processing_controller_test.dart';

void _registerRunningDiscardTests() {
  test('discard during transcription preserves external source', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    final gate = _pauseStage(harness, ProcessingStep.transcribing);

    final run = harness.run(save: false, ownership: AudioOwnership.external);
    await gate.started.future;
    await harness.controller.discardCurrent();
    gate.resume.complete();
    await run;

    await _expectDiscardedRun(harness, sourceRemains: true);
    expect(harness.clientFactory.calls, hasLength(1));
  });
}

({Completer<void> started, Completer<void> resume}) _pauseStage(
  _Harness harness,
  ProcessingStep target,
) {
  final started = Completer<void>();
  final resume = Completer<void>();
  harness.clientFactory.beforeStage = (stage, _) async {
    if (stage != target) return;
    started.complete();
    await resume.future;
  };
  return (started: started, resume: resume);
}

Future<void> _expectDiscardedRun(
  _Harness harness, {
  bool sourceRemains = false,
}) async {
  expect(harness.state.running, isFalse);
  expect(harness.state.error, isNull);
  expect(harness.state.result, isNull);
  expect(await harness.notesRepository.load(), isEmpty);
  expect(await harness.staging.exists(), sourceRemains);
  final retained = Directory('${harness.root.path}/support/audio/retained');
  if (await retained.exists()) expect(await retained.list().toList(), isEmpty);
  await harness.controller.commit();
  expect(await harness.notesRepository.load(), isEmpty);
}
