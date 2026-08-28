import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/models/transcript_note.dart';
import '../services/processing/processing_pipeline.dart';
import 'connections_controller.dart';
import 'notes_controller.dart';
import 'providers.dart';
import 'settings_controller.dart';

/// State of an in-progress (or finished) processing run.
class ProcessingState {
  const ProcessingState({
    this.running = false,
    this.step = ProcessingStep.transcribing,
    this.modelProgress,
    this.fileName = '',
    this.result,
    this.error,
  });

  final bool running;
  final ProcessingStep step;

  /// Download progress (0..1) when a model is being fetched lazily; null otherwise.
  final double? modelProgress;

  final String fileName;
  final TranscriptNote? result;
  final Object? error;

  bool get isDone => result != null;
  bool get hasError => error != null;

  ProcessingState copyWith({
    bool? running,
    ProcessingStep? step,
    double? modelProgress,
    bool clearModelProgress = false,
    String? fileName,
    TranscriptNote? result,
    Object? error,
    bool clearError = false,
  }) => ProcessingState(
    running: running ?? this.running,
    step: step ?? this.step,
    modelProgress: clearModelProgress
        ? null
        : (modelProgress ?? this.modelProgress),
    fileName: fileName ?? this.fileName,
    result: result ?? this.result,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Runs the [ProcessingPipeline] and exposes progress for the processing screen.
class ProcessingController extends Notifier<ProcessingState> {
  @override
  ProcessingState build() => const ProcessingState();

  void reset() => state = const ProcessingState();

  /// Runs the pipeline. When [save] is false the finished note is exposed via
  /// [ProcessingState.result] but NOT persisted — the share overlay shows it as
  /// a preview and persists it only when the user taps "Save" ([commit]).
  Future<void> run(
    ProcessingInput input, {
    String? fileName,
    bool save = true,
  }) async {
    final settings = ref.read(settingsControllerProvider);
    final pipeline = ref.read(processingPipelineProvider);
    final credentials = await _credentialsFor(settings);

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
        callbacks: ProcessingCallbacks(
          onStep: _updateStep,
          onModelProgress: _updateModelProgress,
        ),
      );
      if (save) await ref.read(notesControllerProvider.notifier).add(note);
      state = state.copyWith(
        running: false,
        result: note,
        clearModelProgress: true,
      );
    } catch (e) {
      state = state.copyWith(
        running: false,
        error: e,
        clearModelProgress: true,
      );
    }
  }

  Future<ProcessingCredentials> _credentialsFor(AppSettings settings) async {
    final connections = ref.read(connectionsControllerProvider.notifier);
    final asrApiKey = settings.asrMode.isCloud
        ? await connections.apiKey(settings.asrProvider)
        : '';
    final summaryApiKey =
        settings.summarizeEnabled && settings.summaryMode.isCloud
        ? await connections.apiKey(settings.summaryProvider)
        : '';
    return ProcessingCredentials(
      asrApiKey: asrApiKey,
      summaryApiKey: summaryApiKey,
    );
  }

  void _updateStep(ProcessingStep step) {
    state = state.copyWith(step: step, clearModelProgress: true);
  }

  void _updateModelProgress(double progress) {
    state = state.copyWith(modelProgress: progress);
  }

  /// Persists the current preview result (used by the share overlay's explicit
  /// "Save"). No-op if there's nothing to save.
  Future<void> commit() async {
    final note = state.result;
    if (note == null) return;
    await ref.read(notesControllerProvider.notifier).add(note);
  }
}

final processingControllerProvider =
    NotifierProvider<ProcessingController, ProcessingState>(
      ProcessingController.new,
    );
