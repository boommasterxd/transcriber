import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/models/transcript_note.dart';
import '../services/processing/processing_pipeline.dart';
import '../services/remote/remote_cancellation.dart';
import '../services/storage/audio_cache_manager.dart';
import '../services/storage/managed_audio_file.dart';
import 'connections_controller.dart';
import 'notes_controller.dart';
import 'providers.dart';
import 'settings_controller.dart';

/// State of an in-progress (or finished) processing run.
class ProcessingState {
  const ProcessingState({
    this.running = false,
    this.step = ProcessingStep.transcribing,
    this.fileName = '',
    this.result,
    this.error,
    this.settings,
  });

  final bool running;
  final ProcessingStep step;

  final String fileName;
  final TranscriptNote? result;
  final Object? error;
  final AppSettings? settings;

  bool get isDone => result != null;
  bool get hasError => error != null;

  ProcessingState copyWith({
    bool? running,
    ProcessingStep? step,
    TranscriptNote? result,
    Object? error,
    AppSettings? settings,
  }) => ProcessingState(
    running: running ?? this.running,
    step: step ?? this.step,
    fileName: fileName,
    result: result ?? this.result,
    error: error ?? this.error,
    settings: settings ?? this.settings,
  );
}

/// Runs the [ProcessingPipeline] and exposes progress for the processing screen.
class ProcessingController extends Notifier<ProcessingState> {
  ProcessingInput? _input;
  TranscriptNote? _pendingNote;
  AppSettings? _processingSettings;
  StagedAudioRetention? _stagedAudio;
  bool _retainAudio = false;
  bool _committed = false;
  bool _discardRequested = false;
  bool _persistencePending = false;
  bool _closing = false;
  Future<void>? _finalizeOperation;
  Future<void>? _runOperation;
  RemoteCancellation? _runCancellation;
  _QueuedProcessingRun? _queuedRun;
  Object? _owner;
  int _requestId = 0;

  @override
  ProcessingState build() {
    ref.onDispose(() => _runCancellation?.cancel());
    return const ProcessingState();
  }

  void reset() {
    if (_runOperation == null && _finalizeOperation == null) {
      state = const ProcessingState();
    }
  }

  bool isOwnedBy(Object owner) => identical(owner, _owner);

  /// Runs the pipeline. When [save] is false the finished note is exposed via
  /// [ProcessingState.result] but NOT persisted. The share overlay shows it as
  /// a preview and persists it only when the user taps "Save" ([commit]).
  Future<void> run(
    ProcessingInput input, {
    String? fileName,
    bool save = true,
    Object? owner,
  }) {
    if (_closing) return Future.value();
    if (_runOperation != null || _finalizeOperation != null) {
      if (!_discardRequested || _queuedRun != null) return Future.value();
      _requestId++;
      final queued = _QueuedProcessingRun(input, fileName, save, owner);
      _queuedRun = queued;
      _owner = owner;
      _showRunning(input, fileName, settings: input.settings);
      return queued.completed.future;
    }
    _requestId++;
    _owner = owner;
    return _startRun(input, fileName: fileName, save: save);
  }

  Future<void> _startRun(
    ProcessingInput input, {
    String? fileName,
    required bool save,
  }) {
    final cancellation = RemoteCancellation();
    _runCancellation = cancellation;
    final operation = _executeRun(
      input,
      cancellation,
      fileName: fileName,
      save: save,
    ).whenComplete(_startQueuedRun);
    _runOperation = operation;
    return operation;
  }

  void _startQueuedRun() {
    _runOperation = null;
    _runCancellation = null;
    if (_finalizeOperation != null) return;
    final queued = _queuedRun;
    _queuedRun = null;
    if (queued == null) return;
    _owner = queued.owner;
    _startRun(
      queued.input,
      fileName: queued.fileName,
      save: queued.save,
    ).then(queued.completed.complete, onError: queued.completed.completeError);
  }

  void _showRunning(
    ProcessingInput input,
    String? fileName, {
    AppSettings? settings,
  }) {
    state = ProcessingState(
      running: true,
      fileName: fileName ?? input.audioPath.split('/').last,
      settings: settings,
    );
  }

  Future<void> _executeRun(
    ProcessingInput input,
    RemoteCancellation cancellation, {
    String? fileName,
    required bool save,
  }) async {
    final sameInput = _sameInput(input);
    final retryNote = _persistencePending && sameInput ? _pendingNote : null;
    final abandonedAudio = retryNote == null ? _stagedAudio : null;
    final abandonedInput = !_committed && !sameInput ? _input : null;
    _input = input;
    _pendingNote = retryNote;
    if (retryNote == null) {
      _stagedAudio = null;
      _committed = false;
      _processingSettings = null;
    }
    _persistencePending = false;
    _discardRequested = false;

    _showRunning(
      input,
      fileName,
      settings: _processingSettings ?? input.settings,
    );

    try {
      if (abandonedAudio != null) await _discardStagedAudio(abandonedAudio);
      if (abandonedInput != null) await _discardInput(abandonedInput);
      if (_discardRequested) {
        await _discardCancelledRun(input);
        return;
      }
      final note = retryNote ?? await _process(input, cancellation);
      _pendingNote = note;
      if (_discardRequested) {
        await _discardCancelledRun(input);
        return;
      }
      final result = save
          ? await _save(note, input, finishWhenDiscarded: false)
          : _withAudio(note, input.audio);
      if (_discardRequested) {
        await _discardCancelledRun(input);
        return;
      }
      state = state.copyWith(running: false, result: result);
    } catch (e) {
      if (!ref.mounted) return;
      if (_discardRequested) {
        await _discardCancelledRun(input);
        return;
      }
      state = state.copyWith(running: false, error: e);
    }
  }

  bool _sameInput(ProcessingInput input) =>
      _input?.audioPath == input.audioPath &&
      _input?.audio.ownership == input.audio.ownership &&
      _input?.source == input.source;

  Future<void> _discardCancelledRun(ProcessingInput input) async {
    final staged = _stagedAudio;
    try {
      if (staged != null) await _discardStagedAudio(staged);
    } finally {
      if (!_committed || _persistencePending) await _discardInput(input);
      _input = null;
      _pendingNote = null;
      _stagedAudio = null;
      _processingSettings = null;
      _persistencePending = false;
      if (_queuedRun == null) {
        _owner = null;
        state = const ProcessingState();
      }
    }
  }

  Future<TranscriptNote> _process(
    ProcessingInput input,
    RemoteCancellation cancellation,
  ) async {
    cancellation.throwIfCancelled();
    final settings =
        input.settings ??
        await ref.read(settingsControllerProvider.notifier).readCurrent();
    cancellation.throwIfCancelled();
    _processingSettings = settings;
    _retainAudio = !settings.autoDeleteAudio;
    state = state.copyWith(settings: settings);
    final credentials = await _credentialsFor(settings, cancellation);
    cancellation.throwIfCancelled();
    return ref
        .read(processingPipelineProvider)
        .process(
          ProcessingRequest(
            input: input,
            settings: settings,
            credentials: credentials,
          ),
          callbacks: ProcessingCallbacks(
            onStep: _updateStep,
            cancellation: cancellation,
          ),
        );
  }

  Future<TranscriptNote> _save(
    TranscriptNote note,
    ProcessingInput input, {
    required bool finishWhenDiscarded,
  }) async {
    _persistencePending = true;
    if (!_committed) {
      final saved = await _persist(note, input.audio, finishWhenDiscarded);
      if (saved == null) return note;
      _pendingNote = saved;
      _stagedAudio = null;
      _committed = true;
    }
    await _discardInput(input);
    _persistencePending = false;
    return _pendingNote!;
  }

  Future<TranscriptNote?> _persist(
    TranscriptNote note,
    ManagedAudioFile source,
    bool finishWhenDiscarded,
  ) async {
    final notes = ref.read(notesControllerProvider.notifier);
    if (!_retainAudio || source.ownership == AudioOwnership.retained) {
      final saved = _withAudio(note, source);
      await notes.add(saved);
      return saved;
    }
    final staged = await _prepareRetainedAudio(source);
    if (_discardRequested && !finishWhenDiscarded) return null;
    final saved = _withAudio(note, staged.destination);
    await notes.addWithStagedAudio(saved, staged.promote);
    return saved;
  }

  Future<StagedAudioRetention> _prepareRetainedAudio(
    ManagedAudioFile source,
  ) async {
    final manager = ref.read(audioCacheManagerProvider)..markActive(source);
    try {
      final previous = _stagedAudio;
      if (previous != null) {
        await previous.prepare();
        return previous;
      }
      return _stagedAudio = await manager.stageRetention(source);
    } finally {
      manager.markInactive(source);
    }
  }

  TranscriptNote _withAudio(TranscriptNote note, ManagedAudioFile audio) =>
      _retainAudio
      ? note.copyWith(audioPath: audio.path, audioOwnership: audio.ownership)
      : note;

  Future<ProcessingCredentials> _credentialsFor(
    AppSettings settings,
    RemoteCancellation cancellation,
  ) async {
    final connections = ref.read(connectionsControllerProvider.notifier);
    final asrApiKey = await connections.apiKey(settings.asrProvider);
    cancellation.throwIfCancelled();
    final summaryApiKey = settings.summarizeEnabled
        ? await connections.apiKey(settings.summaryProvider)
        : '';
    return ProcessingCredentials(
      asrApiKey: asrApiKey,
      summaryApiKey: summaryApiKey,
    );
  }

  void _updateStep(ProcessingStep step) {
    if (!_discardRequested) state = state.copyWith(step: step);
  }

  /// Persists the current preview result (used by the share overlay's explicit
  /// "Save"). No-op if there's nothing to save.
  Future<void> commit() {
    if (_closing) return Future.value();
    final pending = _finalizeOperation;
    if (pending != null) return pending;
    if (_committed && !_persistencePending) return Future.value();
    final note = _pendingNote;
    if (state.result == null || note == null) return Future.value();
    final input = _input;
    if (input == null) return Future.value();
    final operation = _save(note, input, finishWhenDiscarded: true)
        .then((saved) {
          if (!_discardRequested) state = state.copyWith(result: saved);
        })
        .whenComplete(_finishFinalization);
    _finalizeOperation = operation;
    return operation;
  }

  bool canRetryLocalSave(Object owner) =>
      !_closing &&
      isOwnedBy(owner) &&
      _persistencePending &&
      _pendingNote != null &&
      _input != null;

  /// Retries only a prepared note belonging to this view.
  Future<bool> retryLocalSave(Object owner) async {
    final note = _pendingNote;
    final input = _input;
    if (!canRetryLocalSave(owner) ||
        note == null ||
        input == null ||
        _runOperation != null ||
        _finalizeOperation != null) {
      return false;
    }
    _discardRequested = false;
    final operation = Future<void>.microtask(() async {
      if (ref.mounted && !_discardRequested) {
        _showRunning(input, state.fileName, settings: _processingSettings);
        await _retrySave(note, input);
      }
      if (ref.mounted && _discardRequested) {
        await _discardCancelledRun(input);
      }
    }).whenComplete(_finishFinalization);
    _finalizeOperation = operation;
    await operation;
    return true;
  }

  Future<void> _retrySave(TranscriptNote note, ProcessingInput input) async {
    try {
      final saved = await _save(note, input, finishWhenDiscarded: false);
      if (ref.mounted && !_discardRequested) {
        state = state.copyWith(running: false, result: saved);
      }
    } catch (error) {
      if (ref.mounted && !_discardRequested) {
        state = state.copyWith(running: false, error: error);
      }
    }
  }

  /// Cancels unfinished work and waits for the dedicated share engine to drain.
  Future<void> close() async {
    _closing = true;
    final running = _runOperation;
    final finalizing = _finalizeOperation;
    try {
      await discardCurrent();
    } finally {
      await Future.wait<void>([?running, ?finalizing]);
    }
  }

  void _finishFinalization() {
    _finalizeOperation = null;
    if (_runOperation == null) _startQueuedRun();
  }

  /// Discards an uncommitted preview or failed input without touching externals.
  Future<void> discardCurrent({Object? owner}) async {
    if (owner != null && !identical(owner, _owner)) return;
    final requestId = _requestId;
    final queued = _queuedRun;
    if (queued != null) {
      _queuedRun = null;
      _owner = null;
      state = const ProcessingState();
      try {
        await _discardInput(queued.input);
      } finally {
        queued.completed.complete();
      }
      return;
    }
    final pending = _finalizeOperation;
    if (pending != null) {
      _discardRequested = true;
      try {
        await pending;
      } catch (_) {
        // A failed commit leaves ownership here, so dismissal may discard it.
      }
      if (requestId != _requestId) return;
    }
    if (_runOperation != null) {
      _discardRequested = true;
      _runCancellation?.cancel();
      return;
    }
    if (_committed) return;
    final input = _input;
    if (input == null) return;
    _discardRequested = true;
    final operation = _discardCancelledRun(input)
        .whenComplete(_finishFinalization);
    _finalizeOperation = operation;
    await operation;
  }

  Future<void> _discardInput(ProcessingInput input) async {
    if (input.audio.ownership != AudioOwnership.temporary) return;
    try {
      await ref.read(audioCacheManagerProvider).discard(input.audio);
    } catch (_) {
      // Temporary audio cleanup is retried by the native cache.
    }
  }

  Future<void> _discardStagedAudio(StagedAudioRetention staged) async {
    await staged.discardStage();
    await ref
        .read(pendingAudioDeletionRecoveryProvider)
        .finalize(staged.destination.path);
  }
}

final class _QueuedProcessingRun {
  _QueuedProcessingRun(this.input, this.fileName, this.save, this.owner);

  final ProcessingInput input;
  final String? fileName;
  final bool save;
  final Object? owner;
  final completed = Completer<void>();
}

final processingControllerProvider =
    NotifierProvider<ProcessingController, ProcessingState>(
      ProcessingController.new,
    );
