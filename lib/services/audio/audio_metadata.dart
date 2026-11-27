import 'package:just_audio/just_audio.dart';

/// Probes the duration of an audio file without playing it.
class AudioMetadata {
  const AudioMetadata();

  Future<Duration?> duration(String path) async {
    final player = AudioPlayer();
    try {
      return await player.setFilePath(path);
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }
}
