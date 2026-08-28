import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/processing/processing_request.dart';

void main() {
  group('ProcessingRequest', () {
    _registerRoundTripTest();
    _registerMissingDurationTest();
  });
}

void _registerRoundTripTest() {
  test('round-trips the foreground job payload', () {
    final settings = AppSettings.initial().copyWith(
      hfToken: 'hf-token',
      whisperThreads: 7,
      summarizeEnabled: false,
    );
    final request = ProcessingRequest(
      input: const ProcessingInput(
        audioPath: '/cache/shared/audio.m4a',
        source: NoteSource.shared,
        knownDurationSec: 42,
      ),
      settings: settings,
      credentials: const ProcessingCredentials(
        asrApiKey: 'asr-key',
        summaryApiKey: 'summary-key',
      ),
    );

    final restored = ProcessingRequest.fromJson(request.toJson());

    expect(restored.input.audioPath, request.input.audioPath);
    expect(restored.input.source, NoteSource.shared);
    expect(restored.input.knownDurationSec, 42);
    expect(restored.settings.hfToken, 'hf-token');
    expect(restored.settings.whisperThreads, 7);
    expect(restored.settings.summarizeEnabled, isFalse);
    expect(restored.credentials.asrApiKey, 'asr-key');
    expect(restored.credentials.summaryApiKey, 'summary-key');
  });
}

void _registerMissingDurationTest() {
  test('preserves a missing known duration', () {
    final request = ProcessingRequest(
      input: const ProcessingInput(
        audioPath: '/cache/audio.ogg',
        source: NoteSource.file,
      ),
      settings: AppSettings.initial(),
      credentials: const ProcessingCredentials(
        asrApiKey: '',
        summaryApiKey: '',
      ),
    );

    final restored = ProcessingRequest.fromJson(request.toJson());

    expect(restored.input.knownDurationSec, isNull);
  });
}
