import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/dictation_state.dart';

void main() {
  test('initial state has no editor, capture feedback, or provider', () {
    final state = DictationState.initial();

    expect(state.phase, DictationPhase.loading);
    expect(state.visible, isFalse);
    expect(state.editorSupported, isFalse);
    expect(state.microphoneGranted, isFalse);
    expect(state.elapsed, Duration.zero);
    expect(state.levels, isEmpty);
    expect(state.preview, isEmpty);
    expect(state.provider, isNull);
    expect(state.modelId, isEmpty);
    expect(state.errorCode, isNull);
    expect(state.isActive, isFalse);
  });

  test(
    'partial progress updates retain editor, model, and capture feedback',
    () {
      final state = _recordingState();
      final next = state.copyWith(
        phase: DictationPhase.correcting,
        progress: state.progress.copyWith(preview: 'Corrected text'),
      );

      expect(next.phase, DictationPhase.correcting);
      expect(next.preview, 'Corrected text');
      expect(next.elapsed, const Duration(seconds: 3));
      expect(next.levels, [0.4]);
      expect(next.visible, isTrue);
      expect(next.editorSupported, isTrue);
      expect(next.microphoneGranted, isTrue);
      expect(next.provider, RemoteProviderId.openai);
      expect(next.modelId, 'live-model');
      expect(state.preview, 'Partial');
    },
  );

  test('ready transition resets progress and error while retaining editor', () {
    final failed = _recordingState().copyWith(
      phase: DictationPhase.error,
      errorCode: 'connection_failed',
    );
    expect(failed.copyWith().errorCode, 'connection_failed');
    expect(failed.copyWith(errorCode: 'quota').errorCode, 'quota');

    final ready = failed.copyWith(
      phase: DictationPhase.ready,
      progress: const DictationProgress(),
      clearError: true,
      errorCode: 'ignored',
    );

    expect(ready.errorCode, isNull);
    expect(ready.preview, isEmpty);
    expect(ready.levels, isEmpty);
    expect(ready.elapsed, Duration.zero);
    expect(ready.editor, same(failed.editor));
    expect(ready.selection, same(failed.selection));
  });

  test('activity is determined by phase including pause and reconnection', () {
    const active = {
      DictationPhase.connecting,
      DictationPhase.recording,
      DictationPhase.correcting,
      DictationPhase.paused,
      DictationPhase.reconnecting,
      DictationPhase.stopping,
    };
    for (final phase in DictationPhase.values) {
      expect(
        DictationState.initial().copyWith(phase: phase).isActive,
        active.contains(phase),
        reason: phase.name,
      );
    }
  });
}

DictationState _recordingState() => DictationState.initial().copyWith(
  phase: DictationPhase.recording,
  editor: const DictationEditorStatus(
    visible: true,
    supported: true,
    microphoneGranted: true,
  ),
  progress: const DictationProgress(
    elapsed: Duration(seconds: 3),
    levels: [0.4],
    preview: 'Partial',
  ),
  selection: const DictationModelSelection(
    provider: RemoteProviderId.openai,
    modelId: 'live-model',
  ),
);
