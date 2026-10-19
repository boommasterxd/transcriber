import 'dart:async';

import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../remote/remote_audio_limits.dart';
import '../storage/audio_cache_manager.dart';
import '../storage/managed_audio_file.dart';
import 'recording_limits.dart';

class RecordingProgress {
  const RecordingProgress({
    required this.dataBytes,
    this.stopped = false,
    this.limited = false,
    this.failed = false,
  });

  final int dataBytes;
  final bool stopped;
  final bool limited;
  final bool failed;
  int get elapsedSec => dataBytes ~/ RecordingLimits.bytesPerSecond;
}

/// Captures provider-compatible mono WAV in the app-owned recording cache.
class AudioRecorderService {
  AudioRecorderService({
    AudioCacheManager? cacheManager,
    Future<String> Function()? recordingDestination,
    Timer Function(Duration, void Function(Timer))? periodicTimer,
  }) : _cacheManager = cacheManager ?? AudioCacheManager() {
    _recordingDestination =
        recordingDestination ?? _cacheManager.recordingDestination;
    _periodicTimer = periodicTimer ?? Timer.periodic;
  }

  final AudioRecorder _recorder = AudioRecorder();
  static const _channel = MethodChannel('app/recording');
  final AudioCacheManager _cacheManager;
  late final Future<String> Function() _recordingDestination;
  late final Timer Function(Duration, void Function(Timer)) _periodicTimer;
  final _progress = StreamController<RecordingProgress>.broadcast();
  final _amplitudes = StreamController<Amplitude>.broadcast();
  Timer? _poller;
  bool _polling = false;
  int _generation = 0;
  String? _currentPath;

  Stream<RecordingProgress> get progressStream => _progress.stream;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts a new recording and returns the destination path.
  Future<String> start({int maxBytes = maxRemoteAudioBytes}) async {
    if (_currentPath != null) throw StateError('A recording already exists.');
    final limits = RecordingLimits(maxBytes);
    if (limits.maxDurationSec < 1 || maxBytes > maxRemoteAudioBytes) {
      throw ArgumentError.value(maxBytes, 'maxBytes');
    }
    final generation = ++_generation;
    final path = await _recordingDestination();
    if (generation != _generation) throw StateError('Recording was cancelled.');
    await _channel.invokeMethod<String>('start', {
      'path': path,
      'maxBytes': limits.captureBytes,
    });
    if (generation != _generation) {
      await _channel.invokeMethod<void>('cancel');
      await _cacheManager.discard(
        ManagedAudioFile(path: path, ownership: AudioOwnership.temporary),
      );
      throw StateError('Recording was cancelled.');
    }
    _currentPath = path;
    _poller = _periodicTimer(
      const Duration(milliseconds: 120),
      (_) => _pollProgress(),
    );
    return path;
  }

  Future<void> pause() => _changeCapture('pause');
  Future<void> resume() => _changeCapture('resume');

  Future<void> _changeCapture(String method) async {
    if (await _channel.invokeMethod<bool>(method) != true) {
      throw StateError('Unable to change recording state.');
    }
  }

  Future<void> _pollProgress() async {
    if (_polling) return;
    _polling = true;
    try {
      final values = await _channel.invokeMapMethod<String, dynamic>(
        'progress',
      );
      if (values == null || _currentPath == null) return;
      _progress.add(
        RecordingProgress(
          dataBytes: values['bytes'] as int,
          stopped: values['stopped'] == true,
          limited: values['limited'] == true,
          failed: values['failed'] == true,
        ),
      );
      final level = values['level'] as double;
      _amplitudes.add(Amplitude(current: level * 45 - 45, max: 0));
      if (values['stopped'] == true) _poller?.cancel();
    } catch (_) {
      // Native capture remains bounded even if the channel is unavailable.
    } finally {
      _polling = false;
    }
  }

  /// Stops recording and returns the finished file path (or null on failure).
  Future<String?> stop() async {
    final path = await _channel.invokeMethod<String>('stop');
    final resolved = path ?? _currentPath;
    _poller?.cancel();
    _currentPath = null;
    return resolved;
  }

  /// Cancels and discards the current recording.
  Future<void> cancel() async {
    _generation++;
    final path = _currentPath;
    await _channel.invokeMethod<void>('cancel');
    _poller?.cancel();
    _currentPath = null;
    if (path != null) {
      await _cacheManager.discard(
        ManagedAudioFile(path: path, ownership: AudioOwnership.temporary),
      );
    }
  }

  /// Live amplitude stream (dBFS) for the waveform visualization.
  Stream<Amplitude> amplitudeStream() => _amplitudes.stream;

  Future<void> dispose() async {
    _generation++;
    _poller?.cancel();
    try {
      if (_currentPath != null) await _channel.invokeMethod<void>('dispose');
    } on PlatformException {
      // Native cleanup releases capture before reporting finalization errors.
    } finally {
      _currentPath = null;
      await _progress.close();
      await _amplitudes.close();
      await _recorder.dispose();
    }
  }
}
