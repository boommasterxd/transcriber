import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import '../storage/storage_paths.dart';

/// Wraps the `record` package to capture microphone audio directly as 16 kHz
/// mono WAV — exactly the format Whisper needs, so no conversion is required.
class AudioRecorderService {
  AudioRecorderService();

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts a new recording and returns the destination path.
  Future<String> start() async {
    final dir = await (await StoragePaths.instance()).audioDir();
    final path = p.join(
      dir.path,
      'rec_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
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
    return path ?? _currentPath;
  }

  /// Cancels and discards the current recording.
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (_) {}
    _currentPath = null;
  }

  /// Live amplitude stream (dBFS) for the waveform visualization.
  Stream<Amplitude> amplitudeStream() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  Future<void> dispose() => _recorder.dispose();
}
