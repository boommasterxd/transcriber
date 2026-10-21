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
      expect(harness.notesRepository.loaded.single.title, 'second.m4a');
      expect(await harness.staging.exists(), isFalse);
      expect(await File(second.audioPath).exists(), isFalse);
      expect(harness.state.running, isFalse);
      expect(harness.state.error, isNull);
    },
  );

  test(
    'dismissed queued input is deleted without provider or save work',
    () async {
      final harness = await _Harness.create(summaryEnabled: false);
      addTearDown(harness.dispose);
      final gate = _pauseStage(harness, ProcessingStep.transcribing);
      final second = await _newInput(harness, 'second.m4a');
      final third = await _newInput(harness, 'third.m4a');
      final secondOwner = Object();
      final thirdOwner = Object();
      final firstRun = harness.run(save: true);
      await gate.started.future;
      await harness.controller.discardCurrent();
      final secondRun = harness.controller.run(second, owner: secondOwner);
      await harness.controller.discardCurrent(owner: secondOwner);
      await secondRun;
      expect(await File(second.audioPath).exists(), isFalse);
      final thirdRun = harness.controller.run(third, owner: thirdOwner);
      await harness.controller.discardCurrent(owner: secondOwner);

      harness.clientFactory.beforeStage = null;
      gate.resume.complete();
      await Future.wait([firstRun, thirdRun]);

      expect(harness.clientFactory.calls, hasLength(2));
      expect(harness.notesRepository.loaded.single.title, 'third.m4a');
      expect(harness.state.result!.title, 'third.m4a');
    },
  );
}

void _registerReentryRecoveryTests() {
  test(
    'queued provider failure preserves input and retries normally',
    () async {
      final harness = await _Harness.create(summaryEnabled: false);
      addTearDown(harness.dispose);
      final gate = _pauseStage(harness, ProcessingStep.transcribing);
      final second = await _newInput(harness, 'second.m4a');
      final firstRun = harness.run(save: false);
      await gate.started.future;
      await harness.controller.discardCurrent();
      final secondRun = harness.controller.run(second);
      harness.clientFactory
        ..beforeStage = null
        ..error = StateError('provider unavailable');
      gate.resume.complete();
      await Future.wait([firstRun, secondRun]);

      expect(harness.state.error, isA<StateError>());
      expect(await File(second.audioPath).exists(), isTrue);
      expect(harness.notesRepository.loaded, isEmpty);
      harness.clientFactory.error = null;
      await harness.controller.run(second);

      expect(harness.state.error, isNull);
      expect(harness.notesRepository.loaded.single.title, 'second.m4a');
      expect(await File(second.audioPath).exists(), isFalse);
    },
  );

  test('duplicate active start does not replace the active input', () async {
    final harness = await _Harness.create(summaryEnabled: false);
    addTearDown(harness.dispose);
    final gate = _pauseStage(harness, ProcessingStep.transcribing);
    final firstRun = harness.run(save: true);
    await gate.started.future;
    await harness.run(save: true);
    expect(harness.clientFactory.calls, hasLength(1));
    gate.resume.complete();
    await firstRun;

    expect(harness.notesRepository.loaded, hasLength(1));
    expect(harness.clientFactory.calls, hasLength(1));
  });
}

void _registerCommitReentryTest() {
  test('Back during committed input cleanup queues the next input', () async {
    late _CleanupPaths paths;
    final harness = await _Harness.create(
      summaryEnabled: false,
      cachePaths: (value) => paths = _CleanupPaths(value),
    );
    addTearDown(harness.dispose);
    harness.notesRepository.afterSave = () => paths.block = true;
    final second = await _newInput(harness, 'second.m4a');
    final firstRun = harness.run(save: true);
    await paths.started.future;
    expect(harness.notesRepository.loaded, hasLength(1));
    await harness.controller.discardCurrent();
    final secondRun = harness.controller.run(second);
    expect(harness.state.fileName, 'second.m4a');
    harness.notesRepository.afterSave = null;
    paths
      ..block = false
      ..resume.complete();
    await Future.wait([firstRun, secondRun]);

    expect(harness.state.result!.title, 'second.m4a');
    expect(harness.notesRepository.loaded, hasLength(2));
    for (final note in harness.notesRepository.loaded) {
      expect(await File(note.audioPath!).exists(), isTrue);
    }
  });

  test(
    'replacement waits for a preview commit without cancelling either save',
    () async {
      final harness = await _Harness.create(summaryEnabled: false);
      addTearDown(harness.dispose);
      final firstOwner = Object();
      final secondOwner = Object();
      await harness.controller.run(
        _originalInput(harness),
        owner: firstOwner,
        save: false,
      );
      final retained = harness.retainedAudio;
      final second = await _newInput(harness, 'second.m4a');
      final gate = Completer<void>();
      final started = Completer<void>();
      harness.notesRepository
        ..gate = gate.future
        ..started = started;
      final commit = harness.controller.commit();
      await started.future;
      final discard = harness.controller.discardCurrent(owner: firstOwner);
      final secondRun = harness.controller.run(second, owner: secondOwner);
      expect(harness.clientFactory.calls, hasLength(1));
      harness.notesRepository.started = null;
      gate.complete();
      await Future.wait([commit, discard, secondRun]);

      expect(harness.notesRepository.loaded.map((note) => note.title), [
        'second.m4a',
        'input.m4a',
      ]);
      expect(await retained.exists(), isTrue);
      expect(harness.state.result!.title, 'second.m4a');
      expect(harness.state.error, isNull);
    },
  );
}

void _registerPreviewCleanupReentryTest() {
  test('old preview cleanup cannot discard a newly started input', () async {
    late _CleanupPaths paths;
    final harness = await _Harness.create(
      summaryEnabled: false,
      cachePaths: (value) => paths = _CleanupPaths(value),
    );
    addTearDown(harness.dispose);
    await harness.run(save: false);
    final retained = harness.retainedAudio;
    final second = await _newInput(harness, 'second.m4a');
    paths.block = true;
    final discard = harness.controller.discardCurrent();
    await paths.started.future;
    final secondRun = harness.controller.run(second);
    paths
      ..block = false
      ..resume.complete();
    await Future.wait([discard, secondRun]);

    expect(await retained.exists(), isFalse);
    expect(await harness.staging.exists(), isFalse);
    expect(harness.state.result!.title, 'second.m4a');
    expect(harness.notesRepository.loaded.single.title, 'second.m4a');
    expect(await harness.retainedAudio.exists(), isTrue);
  });
}

final class _CleanupPaths implements Future<StoragePaths> {
  _CleanupPaths(this.value);

  final StoragePaths value;
  final started = Completer<void>();
  final resume = Completer<void>();
  bool block = false;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(StoragePaths) onValue, {
    Function? onError,
  }) {
    if (!block) return Future.value(value).then(onValue, onError: onError);
    if (!started.isCompleted) started.complete();
    return resume.future.then((_) => onValue(value), onError: onError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
