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

      expect(harness.notesRepository.saved, hasLength(1));
      expect(harness.notesRepository.loaded.single.audioPath, retained.path);
      expect(await retained.exists(), isTrue);
      expect(await harness.staging.exists(), isFalse);
    },
  );

  test('save commits the note before deleting its staging audio', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await harness.run(save: true);

    expect(harness.notesRepository.stagingExistedDuringSave, isTrue);
    expect(await harness.staging.exists(), isFalse);
    expect(harness.notesRepository.loaded, hasLength(1));
    expect(await harness.retainedAudio.exists(), isTrue);
  });

  test(
    'preview plays temporary audio and keeps the original retention choice',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);

      await harness.run(save: false);
      expect(await harness.staging.exists(), isTrue);
      expect(harness.state.result!.audioPath, harness.staging.path);
      expect(harness.state.result!.audioOwnership, AudioOwnership.temporary);
      expect(await harness.retainedFiles(), isEmpty);
      expect(harness.notesRepository.loaded, isEmpty);

      await harness.container
          .read(settingsControllerProvider.notifier)
          .setAutoDelete(true);
      await harness.controller.commit();

      expect(await harness.staging.exists(), isFalse);
      expect(await harness.retainedAudio.readAsBytes(), [1, 2, 3]);
      expect(harness.state.result!.audioOwnership, AudioOwnership.retained);
      expect(harness.notesRepository.loaded, hasLength(1));
      expect(
        harness.notesRepository.loaded.single.audioPath,
        harness.retainedAudio.path,
      );
    },
  );
}

void _registerRetryTests() {
  test('provider failure can retry with the preserved staging audio', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    harness.clientFactory.error = StateError('provider failed');
    await harness.run(save: true);
    expect(await harness.staging.exists(), isTrue);

    harness.clientFactory.error = null;
    await harness.run(save: true);

    await _expectCommitted(harness);
  });

  test('persistence failure preserves staging and allows retry', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    harness.notesRepository.failOnSave = true;

    await harness.run(save: true);
    expect(harness.state.error, isA<StateError>());
    expect(await harness.staging.exists(), isTrue);
    expect(harness.notesRepository.loaded, isEmpty);
    final attempts = harness.clientFactory.calls.length;
    final pending = harness.notesRepository.saved.single.single;
    expect(await File(pending.audioPath!).exists(), isTrue);

    harness.notesRepository.failOnSave = false;
    await harness.run(save: true);

    await _expectCommitted(harness);
    expect(harness.notesRepository.loaded.single.id, pending.id);
    expect(harness.notesRepository.loaded.single.audioPath, pending.audioPath);
    expect(await File(pending.audioPath!).exists(), isTrue);
    expect(harness.clientFactory.calls, hasLength(attempts));
  });
}

Future<void> _expectCommitted(_Harness harness) async {
  expect(harness.state.error, isNull);
  expect(await harness.staging.exists(), isFalse);
  expect(harness.notesRepository.loaded, hasLength(1));
  expect(
    harness.notesRepository.loaded.single.fullTranscriptText,
    'Transcript',
  );
  expect(await harness.retainedAudio.exists(), isTrue);
}
