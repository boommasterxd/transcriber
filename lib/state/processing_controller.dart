import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/models/transcript_note.dart';
import '../services/processing/processing_pipeline.dart';
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
  });

  final bool running;
  final ProcessingStep step;

  final String fileName;
  final TranscriptNote? result;
  final Object? error;

  bool get isDone => result != null;
  bool get hasError => error != null;

  ProcessingState copyWith({
    bool? running,
    ProcessingStep? step,
    String? fileName,
    TranscriptNote? result,
    Object? error,
    bool clearError = false,
  }) => ProcessingState(
    running: running ?? this.running,
    step: step ?? this.step,
    fileName: fileName ?? this.fileName,
    result: result ?? this.result,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Runs the [ProcessingPipeline] and exposes progress for the processing screen.
class ProcessingController extends Notifier<ProcessingState> {
  ProcessingInput? _input;
  TranscriptNote? _pendingNote;
  bool _committed = false;
  bool _discardRequested = false;
  bool _persistencePending = false;
  Future<void>? _commitOperation;
  Future<void>? _runOperation;
  _QueuedProcessingRun? _queuedRun;
  Object? _owner;
  int _requestId = 0;

  @override
  ProcessingState build() => const ProcessingState();

  void reset() {
    if (_runOperation == null && _commitOperation == null) {
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
    if (_runOperation != null || _commitOperation != null) {
      if (!_discardRequested || _queuedRun != null) return Future.value();
      _requestId++;
      final queued = _QueuedProcessingRun(input, fileName, save, owner);
      _queuedRun = queued;
      _owner = owner;
      _showRunning(input, fileName);
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
    final operation = _executeRun(
      input,
      fileName: fileName,
      save: save,
    ).whenComplete(_startQueuedRun);
    _runOperation = operation;
    return operation;
  }

  void _startQueuedRun() {
    _runOperation = null;
    if (_commitOperation != null) return;
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

  void _showRunning(ProcessingInput input, String? fileName) {
    state = ProcessingState(
      running: true,
      fileName: fileName ?? input.audioPath.split('/').last,
    );
  }

  Future<void> _executeRun(
    ProcessingInput input, {
    String? fileName,
    required bool save,
  }) async {
    final retryNote = _persistencePending && _sameInput(input)
        ? _pendingNote
        : null;
    final previousPreview = _pendingNote;
    final discardPrevious =
        retryNote == null && !_committed && previousPreview != null;
    _input = input;
    _pendingNote = retryNote;
    if (retryNote == null) _committed = false;
    _persistencePending = false;
    _discardRequested = false;

    _showRunning(input, fileName);

    try {
      if (discardPrevious) await _discardNoteAudio(previousPreview);
      if (_discardRequested) {
        await _discardCancelledRun(input);
        return;
      }
      final note = retryNote ?? await _process(input);
      _pendingNote = note;
      if (_discardRequested) {
        await _discardCancelledRun(input);
        return;
      }
      if (save) {
        await _save(note, input);
      }
      if (_discardRequested) {
        await _discardCancelledRun(input);
        return;
      }
      state = state.copyWith(running: false, result: note);
    } catch (e) {
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
    final note = _pendingNote;
    if (!_committed && note != null) await _discardNoteAudio(note);
    await _discardInput(input);
    _input = null;
    _pendingNote = null;
    _persistencePending = false;
    if (_queuedRun == null) state = const ProcessingState();
  }

  Future<TranscriptNote> _process(ProcessingInput input) async {
    final settings = ref.read(settingsControllerProvider);
    final credentials = await _credentialsFor(settings);
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
            isCancelled: () => _discardRequested,
          ),
        );
  }

  Future<void> _save(TranscriptNote note, ProcessingInput input) async {
    _persistencePending = true;
    if (!_committed) {
      await ref.read(notesControllerProvider.notifier).add(note);
      _committed = true;
    }
    await _discardInput(input);
    _persistencePending = false;
  }

  Future<ProcessingCredentials> _credentialsFor(AppSettings settings) async {
    final connections = ref.read(connectionsControllerProvider.notifier);
    final asrApiKey = await connections.apiKey(settings.asrProvider);
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
    final pending = _commitOperation;
    if (pending != null) return pending;
    if (_committed) return Future.value();
    final note = state.result;
    if (note == null) return Future.value();
    final input = _input;
    if (input == null) return Future.value();
    final operation = _save(note, input).whenComplete(() {
      _commitOperation = null;
      if (_runOperation == null) _startQueuedRun();
    });
    _commitOperation = operation;
    return operation;
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
    final pending = _commitOperation;
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
      return;
    }
    if (_committed) return;
    final note = state.result ?? _pendingNote;
    final input = _input;
    if (note != null) {
      await _discardNoteAudio(note);
    }
    if (input != null) await _discardInput(input);
    if (requestId != _requestId) return;
    _input = null;
    _pendingNote = null;
    _persistencePending = false;
  }

  Future<void> _discardInput(ProcessingInput input) =>
      ref.read(audioCacheManagerProvider).discard(input.audio);

  Future<void> _discardNoteAudio(TranscriptNote note) => ref
      .read(audioCacheManagerProvider)
      .deleteRetainedPath(
        note.audioOwnership == AudioOwnership.retained ? note.audioPath : null,
      );
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
