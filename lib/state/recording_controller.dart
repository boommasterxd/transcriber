import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import 'providers.dart';

class RecordingState {
  const RecordingState({
    this.active = false,
    this.paused = false,
    this.elapsedSec = 0,
    this.levels = const [],
    this.path,
  });

  final bool active;
  final bool paused;
  final int elapsedSec;

  /// Rolling normalized amplitude values (0..1) for the live waveform.
  final List<double> levels;
  final String? path;

  RecordingState copyWith({
    bool? active,
    bool? paused,
    int? elapsedSec,
    List<double>? levels,
    String? path,
  }) => RecordingState(
    active: active ?? this.active,
    paused: paused ?? this.paused,
    elapsedSec: elapsedSec ?? this.elapsedSec,
    levels: levels ?? this.levels,
    path: path ?? this.path,
  );
}

/// Drives the recording screen: elapsed timer + live amplitude levels.
class RecordingController extends Notifier<RecordingState> {
  Timer? _ticker;
  StreamSubscription<Amplitude>? _ampSub;

  static const _maxBars = 42;

  @override
  RecordingState build() {
    ref.onDispose(_teardown);
    return const RecordingState();
  }

  Future<bool> hasPermission() =>
      ref.read(audioRecorderProvider).hasPermission();

  Future<bool> start() async {
    final recorder = ref.read(audioRecorderProvider);
    if (!await recorder.hasPermission()) {
      return false;
    }
    final path = await recorder.start();
    state = RecordingState(
      active: true,
      path: path,
      levels: List.filled(_maxBars, 0.12),
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.paused) {
        state = state.copyWith(elapsedSec: state.elapsedSec + 1);
      }
    });
    _ampSub = recorder.amplitudeStream().listen(_onAmplitude);
    return true;
  }

  void _onAmplitude(Amplitude amp) {
    if (state.paused) return;
    // Map dBFS (~ -45..0) to a 0..1 height.
    final normalized = ((amp.current + 45) / 45).clamp(0.05, 1.0);
    final next = [...state.levels, normalized];
    if (next.length > _maxBars) next.removeRange(0, next.length - _maxBars);
    state = state.copyWith(levels: next);
  }

  Future<void> togglePause() async {
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
    await ref.read(audioRecorderProvider).cancel();
    _teardown();
    state = const RecordingState();
  }

  void _teardown() {
    _ticker?.cancel();
    _ticker = null;
    _ampSub?.cancel();
    _ampSub = null;
  }
}

final recordingControllerProvider =
    NotifierProvider<RecordingController, RecordingState>(
      RecordingController.new,
    );
