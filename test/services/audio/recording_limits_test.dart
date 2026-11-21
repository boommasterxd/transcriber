import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/audio/recording_limits.dart';
import 'package:transcriber/services/remote/remote_audio_limits.dart';

void main() {
  test(
    'resolves the selected audio endpoint limit including model defaults',
    () {
      for (final entry in [
        (RemoteProviderId.openai, 'gpt-audio', maxInlineAudioBytes),
        (RemoteProviderId.openai, 'gpt-transcribe', maxRemoteAudioBytes),
        (RemoteProviderId.openai, 'whisper-1', maxRemoteAudioBytes),
        (RemoteProviderId.google, 'gemini-3.7-flash', maxRemoteAudioBytes),
        (RemoteProviderId.google, 'gemini-3.5-transcribe', maxRemoteAudioBytes),
      ]) {
        final settings = AppSettings(
          transcription: TranscriptionSettings(
            provider: entry.$1,
            models: {entry.$1: entry.$2},
          ),
        );
        expect(RecordingLimits.fromSettings(settings).maxBytes, entry.$3);
      }
      expect(
        RecordingLimits.fromSettings(const AppSettings()).maxBytes,
        maxRemoteAudioBytes,
      );
    },
  );

  test('reserves the RIFF header and only promises complete PCM seconds', () {
    for (final cap in [
      32044,
      32045,
      maxInlineAudioBytes,
      maxRemoteAudioBytes,
    ]) {
      final limit = RecordingLimits(cap);
      expect(limit.captureBytes, lessThanOrEqualTo(cap));
      expect(limit.captureBytes + 32000, greaterThan(cap));
      expect((limit.captureBytes - 44) % 32000, 0);
    }
    expect(const RecordingLimits(maxInlineAudioBytes).maxDurationSec, 655);
    expect(const RecordingLimits(maxRemoteAudioBytes).maxDurationSec, 3276);
  });
}
