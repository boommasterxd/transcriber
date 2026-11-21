import 'package:test/test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcription_language.dart';
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

  test('maps language hints to each provider protocol', () {
    expect(
      LiveDictationModelCatalog.languageCodeFor(
        RemoteProviderId.google,
        TranscriptionLanguage.de,
      ),
      'de-DE',
    );
    expect(
      LiveDictationModelCatalog.languageCodeFor(
        RemoteProviderId.google,
        TranscriptionLanguage.en,
      ),
      'en-US',
    );
    expect(
      LiveDictationModelCatalog.languageCodeFor(
        RemoteProviderId.openai,
        TranscriptionLanguage.de,
      ),
      'de',
    );
    expect(
      LiveDictationModelCatalog.languageCodeFor(
        RemoteProviderId.google,
        TranscriptionLanguage.auto,
      ),
      isNull,
    );
  });
}
