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
    final previousPreview = _pendingNote;
    if (!_committed && previousPreview != null) {
      await _discardNoteAudio(previousPreview);
    }
    final settings = ref.read(settingsControllerProvider);
    final pipeline = ref.read(processingPipelineProvider);
    final credentials = await _credentialsFor(settings);
    _input = input;
    _pendingNote = null;
    _committed = false;
    _discardRequested = false;

    state = ProcessingState(
      running: true,
      step: ProcessingStep.transcribing,
      fileName: fileName ?? input.audioPath.split('/').last,
    );

    try {
      final note = await pipeline.process(
        ProcessingRequest(
          input: input,
          settings: settings,
          credentials: credentials,
        ),
        callbacks: ProcessingCallbacks(onStep: _updateStep),
      );
      _pendingNote = note;
      if (_discardRequested) {
        await _discardNoteAudio(note);
        await _discardInput(input);
        state = const ProcessingState();
        return;
      }
      if (save) {
        await ref.read(notesControllerProvider.notifier).add(note);
        _committed = true;
        await _discardInput(input);
      }
      state = state.copyWith(running: false, result: note);
    } catch (e) {
      if (_discardRequested) {
        await ref.read(audioCacheManagerProvider).discard(input.audio);
        state = const ProcessingState();
        return;
      }
      state = state.copyWith(running: false, error: e);
    }
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
  Future<void> commit() async {
    if (_committed) return;
    final note = state.result;
    if (note == null) return;
    await ref.read(notesControllerProvider.notifier).add(note);
    _committed = true;
    final input = _input;
    if (input != null) await _discardInput(input);
  }

  /// Discards an uncommitted preview or failed input without touching externals.
  Future<void> discardCurrent() async {
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
