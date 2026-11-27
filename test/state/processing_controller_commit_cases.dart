part of 'processing_controller_test.dart';

void _registerCommitTests() {
  test(
    'dismissal waits for pending commit without deleting saved audio',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      await harness.run(save: false);
      final gate = Completer<void>();
      final started = Completer<void>();
      harness.notesRepository.gate = gate.future;
      harness.notesRepository.started = started;

      final commit = harness.controller.commit();
      await started.future;
      final retained = File(harness.notesRepository.attempted!.audioPath!);
      final duplicateCommit = harness.controller.commit();
      final discard = harness.controller.discardCurrent();
      expect(await retained.exists(), isTrue);
      expect(await harness.staging.exists(), isTrue);
      gate.complete();
      await Future.wait([commit, duplicateCommit, discard]);

      expect(harness.notesRepository.attempts, 1);
      expect(
        (await harness.notesRepository.load()).single.audioPath,
        retained.path,
      );
      expect(await retained.exists(), isTrue);
      expect(await harness.staging.exists(), isFalse);
    },
  );
}

void _registerRetryTests() {
  test('persistence failure preserves staging and allows retry', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    final owner = Object();
    harness.notesRepository.failOnSave = true;

    await harness.run(save: true, owner: owner);
    expect(harness.state.error, isA<StateError>());
    expect(await harness.staging.exists(), isTrue);
    expect(await harness.notesRepository.load(), isEmpty);
    final attempts = harness.clientFactory.calls.length;
    final pending = harness.notesRepository.attempted!;
    expect(await File(pending.audioPath!).exists(), isTrue);

    harness.notesRepository.failOnSave = false;
    expect(harness.controller.canRetryLocalSave(owner), isTrue);
    expect(await harness.controller.retryLocalSave(Object()), isFalse);
    expect(await harness.controller.retryLocalSave(owner), isTrue);

    expect(harness.state.error, isNull);
    expect(await harness.staging.exists(), isFalse);
    final saved = (await harness.notesRepository.load()).single;
    expect(saved.id, pending.id);
    expect(saved.fullTranscriptText, 'Transcript');
    expect(saved.audioPath, pending.audioPath);
    expect(await File(pending.audioPath!).exists(), isTrue);
    expect(harness.clientFactory.calls, hasLength(attempts));
  });
}
