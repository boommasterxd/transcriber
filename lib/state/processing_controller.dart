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

  @override
  ProcessingState build() => const ProcessingState();

  void reset() => state = const ProcessingState();

  /// Runs the pipeline. When [save] is false the finished note is exposed via
  /// [ProcessingState.result] but NOT persisted. The share overlay shows it as
  /// a preview and persists it only when the user taps "Save" ([commit]).
  Future<void> run(
    ProcessingInput input, {
    String? fileName,
    bool save = true,
  }) async {
    if (state.running) return;
    final retryNote = _persistencePending && _sameInput(input)
        ? _pendingNote
        : null;
    final previousPreview = _pendingNote;
    if (retryNote == null && !_committed && previousPreview != null) {
      await _discardNoteAudio(previousPreview);
    }
    _input = input;
    _pendingNote = retryNote;
    if (retryNote == null) _committed = false;
    _persistencePending = false;
    _discardRequested = false;

    state = ProcessingState(
      running: true,
      step: ProcessingStep.transcribing,
      fileName: fileName ?? input.audioPath.split('/').last,
    );

    try {
      final note = retryNote ?? await _process(input);
      _pendingNote = note;
      if (_discardRequested) {
        await _discardCancelledRun(input);
        return;
      }
      if (save) {
        await _save(note, input);
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
    state = const ProcessingState();
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
          callbacks: ProcessingCallbacks(onStep: _updateStep),
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
    state = state.copyWith(step: step);
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
    });
    _commitOperation = operation;
    return operation;
  }

  /// Discards an uncommitted preview or failed input without touching externals.
  Future<void> discardCurrent() async {
    final pending = _commitOperation;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // A failed commit leaves ownership here, so dismissal may discard it.
      }
    }
    if (_committed) return;
    if (state.running) {
      _discardRequested = true;
      return;
    }
    final note = state.result ?? _pendingNote;
    if (note != null) {
      await _discardNoteAudio(note);
    }
    final input = _input;
    if (input != null) await _discardInput(input);
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

final processingControllerProvider =
    NotifierProvider<ProcessingController, ProcessingState>(
      ProcessingController.new,
    );
