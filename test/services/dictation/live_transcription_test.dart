import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';

void main() {
  test('catalog exposes only provider-specific live models and PCM rates', () {
    expect(LiveDictationModelCatalog.modelByProvider, {
      RemoteProviderId.openai: 'gpt-live-transcribe',
      RemoteProviderId.google: 'gemini-3.5-transcribe-live',
    });
    expect(
      LiveDictationModelCatalog.sampleRateFor(RemoteProviderId.openai),
      24000,
    );
    expect(
      LiveDictationModelCatalog.sampleRateFor(RemoteProviderId.google),
      16000,
    );
  });
}
