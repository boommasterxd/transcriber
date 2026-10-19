import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../services/audio/audio_recorder_service.dart';
import '../services/audio/recording_limits.dart';
import 'providers.dart';
import 'settings_controller.dart';

class RecordingBoundary {
  const RecordingBoundary({
    this.maxDurationSec = 0,
    this.reached = false,
    this.failed = false,
  });
  final int maxDurationSec;
  final bool reached;
  final bool failed;
}

class RecordingState {
  const RecordingState({
    this.active = false,
    this.paused = false,
    this.elapsedSec = 0,
    this.levels = const [],
    this.path,
    this.boundary = const RecordingBoundary(),
  });

  final bool active;
  final bool paused;
  final int elapsedSec;

  /// Rolling normalized amplitude values (0..1) for the live waveform.
  final List<double> levels;
  final String? path;
  final RecordingBoundary boundary;

  RecordingState copyWith({
    bool? active,
    bool? paused,
    int? elapsedSec,
    List<double>? levels,
    String? path,
    RecordingBoundary? boundary,
  }) => RecordingState(
    active: active ?? this.active,
    paused: paused ?? this.paused,
    elapsedSec: elapsedSec ?? this.elapsedSec,
    levels: levels ?? this.levels,
    path: path ?? this.path,
    boundary: boundary ?? this.boundary,
  );
}

/// Drives the recording screen: elapsed timer + live amplitude levels.
class RecordingController extends Notifier<RecordingState> {
  Timer? _ticker;
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<RecordingProgress>? _progressSub;
  bool _starting = false;
  int _generation = 0;

  static const _maxBars = 42;

  @override
  RecordingState build() {
    ref.onDispose(_teardown);
    return const RecordingState();
  }

  Future<bool> hasPermission() =>
      ref.read(audioRecorderProvider).hasPermission();

  Future<bool> start() async {
    if (_starting || state.path != null) return true;
    _starting = true;
    try {
      return await _startCapture();
    } finally {
      _starting = false;
    }
  }

  Future<bool> _startCapture() async {
    final generation = _generation;
    final recorder = ref.read(audioRecorderProvider);
    if (!await recorder.hasPermission()) {
      return false;
    }
    if (!ref.mounted || generation != _generation) return false;
    final limits = RecordingLimits.fromSettings(
      ref.read(settingsControllerProvider),
    );
    final path = await recorder.start(maxBytes: limits.maxBytes);
    if (!ref.mounted || generation != _generation) {
      await recorder.cancel();
      return false;
    }
    state = RecordingState(
      active: true,
      path: path,
      levels: List.filled(_maxBars, 0.12),
      boundary: RecordingBoundary(maxDurationSec: limits.maxDurationSec),
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.active && !state.paused) {
        state = state.copyWith(
          elapsedSec: (state.elapsedSec + 1).clamp(0, limits.maxDurationSec),
        );
      }
    });
    _ampSub = recorder.amplitudeStream().listen(_onAmplitude);
    _progressSub = recorder.progressStream.listen(_onProgress);
    return true;
  }

  void _onProgress(RecordingProgress progress) {
    state = state.copyWith(
      active: !progress.stopped,
      paused: progress.stopped || state.paused,
      elapsedSec: progress.elapsedSec.clamp(0, state.boundary.maxDurationSec),
      boundary: RecordingBoundary(
        maxDurationSec: state.boundary.maxDurationSec,
        reached: progress.limited,
        failed: progress.failed,
      ),
    );
    if (progress.stopped) _ticker?.cancel();
  }

  void _onAmplitude(Amplitude amp) {
    if (!state.active || state.paused) return;
    // Map dBFS (~ -45..0) to a 0..1 height.
    final normalized = ((amp.current + 45) / 45).clamp(0.05, 1.0);
    final next = [...state.levels, normalized];
    if (next.length > _maxBars) next.removeRange(0, next.length - _maxBars);
    state = state.copyWith(levels: next);
  }

  Future<void> togglePause() async {
    if (!state.active) return;
    final recorder = ref.read(audioRecorderProvider);
    if (state.paused) {
      await recorder.resume();
      state = state.copyWith(paused: false);
    } else {
      await recorder.pause();
      state = state.copyWith(paused: true);
    }
  }

  /// Stops and returns (path, durationSec), or null if nothing was captured.
  Future<({String path, int durationSec})?> stop() async {
    final recorder = ref.read(audioRecorderProvider);
    final duration = state.elapsedSec;
    final path = await recorder.stop();
    _teardown();
    state = const RecordingState();
    if (path == null) return null;
    return (path: path, durationSec: duration < 1 ? 1 : duration);
  }

  Future<void> cancel() async {
    _generation++;
    await ref.read(audioRecorderProvider).cancel();
    _teardown();
    state = const RecordingState();
  }

  void _teardown() {
    _generation++;
    _ticker?.cancel();
    _ticker = null;
    _ampSub?.cancel();
    _ampSub = null;
    _progressSub?.cancel();
    _progressSub = null;
  }
}

final recordingControllerProvider =
    NotifierProvider<RecordingController, RecordingState>(
      RecordingController.new,
    );
