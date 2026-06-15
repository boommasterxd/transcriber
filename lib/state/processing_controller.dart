import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }) =>
      ProcessingState(
        running: running ?? this.running,
        step: step ?? this.step,
        modelProgress: clearModelProgress ? null : (modelProgress ?? this.modelProgress),
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

  Future<void> run({
    required String audioPath,
    required NoteSource source,
    String? fileName,
    int? knownDurationSec,
  }) async {
    final settings = ref.read(settingsControllerProvider);
    final strings = ref.read(stringsProvider);
    final pipeline = ref.read(processingPipelineProvider);

    var apiKey = '';
    if (settings.mode.isCloud) {
      apiKey = await ref.read(connectionsControllerProvider.notifier).apiKey(settings.provider);
    }

    state = ProcessingState(
      running: true,
      step: ProcessingStep.transcribing,
      fileName: fileName ?? audioPath.split('/').last,
    );

    try {
      final note = await pipeline.process(
        audioPath: audioPath,
        source: source,
        settings: settings,
        strings: strings,
        apiKey: apiKey,
        knownDurationSec: knownDurationSec,
        onStep: (step) => state = state.copyWith(step: step, clearModelProgress: true),
        onModelProgress: (p) => state = state.copyWith(modelProgress: p),
      );
      await ref.read(notesControllerProvider.notifier).add(note);
      state = state.copyWith(running: false, result: note, clearModelProgress: true);
    } catch (e) {
      state = state.copyWith(running: false, error: e, clearModelProgress: true);
    }
  }
}

final processingControllerProvider =
    NotifierProvider<ProcessingController, ProcessingState>(ProcessingController.new);
