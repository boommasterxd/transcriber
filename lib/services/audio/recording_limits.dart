import '../../data/models/app_settings.dart';
import '../remote/remote_audio_limits.dart';

/// Exact PCM16 mono 16 kHz WAV budget, including its 44-byte RIFF header.
class RecordingLimits {
  const RecordingLimits(this.maxBytes);

  factory RecordingLimits.fromSettings(AppSettings settings) => RecordingLimits(
    remoteAudioLimit(
      settings.asrProvider,
      settings.asrModelId(settings.asrProvider),
    ),
  );

  static const headerBytes = 44;
  static const bytesPerSecond = 32000;
  final int maxBytes;

  /// Use complete seconds so displayed duration never promises extra capacity.
  int get maxDurationSec => (maxBytes - headerBytes) ~/ bytesPerSecond;
  int get captureBytes => headerBytes + maxDurationSec * bytesPerSecond;
}
