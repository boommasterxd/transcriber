import 'package:just_audio/just_audio.dart';

/// Probes the duration of an audio file without playing it.
class AudioMetadata {
  const AudioMetadata();

  Future<int> durationSeconds(String path) async {
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(path);
      return duration?.inSeconds ?? 0;
    } catch (_) {
      return 0;
    } finally {
      await player.dispose();
    }
  }
}
