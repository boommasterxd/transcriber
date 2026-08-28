import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/processing/processing_request.dart';
import 'package:transcriber/services/storage/managed_audio_file.dart';

void main() {
  group('ProcessingRequest', () {
    test('exposes the managed audio path', () {
      final request = _request(
        const ManagedAudioFile(
          path: '/cache/shared/audio.m4a',
          ownership: AudioOwnership.temporary,
        ),
      );

      expect(request.input.audioPath, '/cache/shared/audio.m4a');
      expect(request.input.audio.ownership, AudioOwnership.temporary);
    });

    test('adds a known duration without changing audio ownership', () {
      final request = _request(
        const ManagedAudioFile(
          path: '/cache/audio.ogg',
          ownership: AudioOwnership.retained,
        ),
      );

      final updated = request.withKnownDuration(42);

      expect(request.input.knownDurationSec, isNull);
      expect(updated.input.knownDurationSec, 42);
      expect(updated.input.audio, same(request.input.audio));
      expect(updated.settings, same(request.settings));
      expect(updated.credentials, same(request.credentials));
    });
  });
}

ProcessingRequest _request(ManagedAudioFile audio) => ProcessingRequest(
  input: ProcessingInput(audio: audio, source: NoteSource.shared),
  settings: AppSettings.initial(),
  credentials: const ProcessingCredentials(
    asrApiKey: 'asr-key',
    summaryApiKey: 'summary-key',
  ),
);
