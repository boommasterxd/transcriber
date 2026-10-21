part of 'processing_controller_test.dart';

void _registerRunningDiscardTests() {
  for (final stage in ProcessingStep.values) {
    test('discard during $stage skips later work and removes audio', () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      final gate = _pauseStage(harness, stage);

      final run = harness.run(save: true);
      await gate.started.future;
      await harness.controller.discardCurrent();
      expect(await harness.staging.exists(), isTrue);
      gate.resume.complete();
      await run;

      await _expectDiscardedRun(harness);
      expect(harness.clientFactory.calls, hasLength(stage.index + 1));
    });
  }

  for (final stage in ProcessingStep.values) {
    test(
      'discarded $stage failure cleans input without exposing error',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.dispose);
        final failure = StateError('provider failed');
        if (stage == ProcessingStep.transcribing) {
          harness.clientFactory.error = failure;
        } else {
          harness.clientFactory.summaryError = failure;
        }
        final gate = _pauseStage(harness, stage);

        final run = harness.run(save: false);
        await gate.started.future;
        await harness.controller.discardCurrent();
        gate.resume.complete();
        await run;

        await _expectDiscardedRun(harness);
      },
    );
  }

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

  test('discard after retention starts removes the resulting copy', () async {
    late _Harness harness;
    Future<void>? discard;
    final uuid = _RetentionUuid(() {
      discard = harness.controller.discardCurrent();
    });
    harness = await _Harness.create(retentionUuid: uuid);
    addTearDown(harness.dispose);

    await harness.run(save: true);
    await discard;

    expect(uuid.calls, 1);
    await _expectDiscardedRun(harness);
  });
}

({Completer<void> started, Completer<void> resume}) _pauseStage(
  _Harness harness,
  ProcessingStep target,
) {
  final started = Completer<void>();
  final resume = Completer<void>();
  harness.clientFactory.beforeStage = (stage) async {
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
  expect(harness.notesRepository.loaded, isEmpty);
  expect(await harness.staging.exists(), sourceRemains);
  final retained = Directory('${harness.root.path}/support/audio/retained');
  if (await retained.exists()) expect(await retained.list().toList(), isEmpty);
  await harness.controller.commit();
  expect(harness.notesRepository.loaded, isEmpty);
}

final class _RetentionUuid extends Uuid {
  _RetentionUuid(this.onRetain);

  final void Function() onRetain;
  int calls = 0;

  @override
  String v4({Map<String, dynamic>? options, V4Options? config}) {
    calls++;
    onRetain();
    return super.v4(config: config);
  }
}
