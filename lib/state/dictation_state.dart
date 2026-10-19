import '../data/models/remote_provider.dart';

enum DictationPhase {
  loading,
  ready,
  connecting,
  recording,
  correcting,
  paused,
  reconnecting,
  stopping,
  unavailable,
  error,
}

class DictationState {
  const DictationState({
    required this.phase,
    required this.editor,
    required this.progress,
    required this.selection,
    required this.errorCode,
  });

  factory DictationState.initial() => const DictationState(
    phase: DictationPhase.loading,
    editor: DictationEditorStatus(
      visible: false,
      supported: false,
      microphoneGranted: false,
    ),
    progress: DictationProgress(),
    selection: DictationModelSelection(provider: null, modelId: ''),
    errorCode: null,
  );

  final DictationPhase phase;
  final DictationEditorStatus editor;
  final DictationProgress progress;
  final DictationModelSelection selection;
  final String? errorCode;

  bool get visible => editor.visible;
  bool get editorSupported => editor.supported;
  bool get microphoneGranted => editor.microphoneGranted;
  Duration get elapsed => progress.elapsed;
  List<double> get levels => progress.levels;
  String get preview => progress.preview;
  RemoteProviderId? get provider => selection.provider;
  String get modelId => selection.modelId;

  bool get isActive => switch (phase) {
    DictationPhase.connecting ||
    DictationPhase.recording ||
    DictationPhase.correcting ||
    DictationPhase.paused ||
    DictationPhase.reconnecting ||
    DictationPhase.stopping => true,
    _ => false,
  };

  DictationState copyWith({
    DictationPhase? phase,
    DictationEditorStatus? editor,
    DictationProgress? progress,
    DictationModelSelection? selection,
    String? errorCode,
    bool clearError = false,
  }) => DictationState(
    phase: phase ?? this.phase,
    editor: editor ?? this.editor,
    progress: progress ?? this.progress,
    selection: selection ?? this.selection,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
  );
}

/// Availability and permission of the current editor.
class DictationEditorStatus {
  const DictationEditorStatus({
    required this.visible,
    required this.supported,
    required this.microphoneGranted,
  });

  final bool visible;
  final bool supported;
  final bool microphoneGranted;
}

/// Transient capture feedback, reset together at session boundaries.
class DictationProgress {
  const DictationProgress({
    this.elapsed = Duration.zero,
    this.levels = const [],
    this.preview = '',
  });

  final Duration elapsed;
  final List<double> levels;
  final String preview;

  DictationProgress copyWith({
    Duration? elapsed,
    List<double>? levels,
    String? preview,
  }) => DictationProgress(
    elapsed: elapsed ?? this.elapsed,
    levels: levels ?? this.levels,
    preview: preview ?? this.preview,
  );
}

/// Provider and model label are updated atomically without retaining credentials.
class DictationModelSelection {
  const DictationModelSelection({
    required this.provider,
    required this.modelId,
  });

  final RemoteProviderId? provider;
  final String modelId;
}
