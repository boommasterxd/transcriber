import 'dart:async';

import 'package:record/record.dart';

import '../storage/audio_cache_manager.dart';
import '../storage/managed_audio_file.dart';

/// Captures provider-compatible mono WAV in the app-owned recording cache.
class AudioRecorderService {
  AudioRecorderService({AudioCacheManager? cacheManager})
    : _cacheManager = cacheManager ?? AudioCacheManager();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioCacheManager _cacheManager;
  String? _currentPath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts a new recording and returns the destination path.
  Future<String> start() async {
    final path = await _cacheManager.recordingDestination();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _currentPath = path;
    return path;
  }

  Future<void> pause() => _recorder.pause();
  Future<void> resume() => _recorder.resume();

  /// Stops recording and returns the finished file path (or null on failure).
  Future<String?> stop() async {
    final path = await _recorder.stop();
    final resolved = path ?? _currentPath;
    _currentPath = null;
    return resolved;
  }

  /// Cancels and discards the current recording.
  Future<void> cancel() async {
    final path = _currentPath;
    try {
      await _recorder.cancel();
    } catch (_) {}
    _currentPath = null;
    if (path != null) {
      await _cacheManager.discard(
        ManagedAudioFile(path: path, ownership: AudioOwnership.temporary),
      );
    }
  }

  /// Live amplitude stream (dBFS) for the waveform visualization.
  Stream<Amplitude> amplitudeStream() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  Future<void> dispose() => _recorder.dispose();
}
