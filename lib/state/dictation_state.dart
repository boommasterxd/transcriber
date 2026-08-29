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
    required this.visible,
    required this.editorSupported,
    required this.microphoneGranted,
    required this.elapsed,
    required this.levels,
    required this.preview,
    required this.provider,
    required this.modelId,
    required this.errorCode,
  });

  factory DictationState.initial() => const DictationState(
    phase: DictationPhase.loading,
    visible: false,
    editorSupported: false,
    microphoneGranted: false,
    elapsed: Duration.zero,
    levels: [],
    preview: '',
    provider: null,
    modelId: '',
    errorCode: null,
  );

  final DictationPhase phase;
  final bool visible;
  final bool editorSupported;
  final bool microphoneGranted;
  final Duration elapsed;
  final List<double> levels;
  final String preview;
  final RemoteProviderId? provider;
  final String modelId;
  final String? errorCode;

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
    bool? visible,
    bool? editorSupported,
    bool? microphoneGranted,
    Duration? elapsed,
    List<double>? levels,
    String? preview,
    RemoteProviderId? provider,
    String? modelId,
    String? errorCode,
    bool clearError = false,
  }) => DictationState(
    phase: phase ?? this.phase,
    visible: visible ?? this.visible,
    editorSupported: editorSupported ?? this.editorSupported,
    microphoneGranted: microphoneGranted ?? this.microphoneGranted,
    elapsed: elapsed ?? this.elapsed,
    levels: levels ?? this.levels,
    preview: preview ?? this.preview,
    provider: provider ?? this.provider,
    modelId: modelId ?? this.modelId,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
  );
}
