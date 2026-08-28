import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/audio_ownership.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcription_language.dart';

void main() {
  group('RemoteProviderId', () {
    test('round-trips every stable provider id', () {
      expect(RemoteProviderId.values.map((provider) => provider.id), [
        'openai',
        'google',
      ]);
      for (final provider in RemoteProviderId.values) {
        expect(RemoteProviderId.fromId(provider.id), provider);
      }
    });

    test('falls back to Google for invalid provider ids', () {
      for (final value in <String?>[null, '', 'OpenAI', 'unknown']) {
        expect(RemoteProviderId.fromId(value), RemoteProviderId.google);
      }
    });
  });

  group('TranscriptionLanguage', () {
    test('round-trips every stable language code', () {
      expect(TranscriptionLanguage.values.map((language) => language.code), [
        'auto',
        'de',
        'en',
      ]);
      for (final language in TranscriptionLanguage.values) {
        expect(TranscriptionLanguage.fromCode(language.code), language);
      }
    });

    test('falls back to automatic detection for invalid codes', () {
      for (final value in <String?>[null, '', 'DE', 'fr']) {
        expect(
          TranscriptionLanguage.fromCode(value),
          TranscriptionLanguage.auto,
        );
      }
    });
  });

  group('AudioOwnership', () {
    test('round-trips every stable ownership id', () {
      expect(AudioOwnership.values.map((ownership) => ownership.id), [
        'external',
        'temporary',
        'retained',
      ]);
      for (final ownership in AudioOwnership.values) {
        expect(AudioOwnership.fromId(ownership.id), ownership);
      }
    });

    test('falls back to external for absent or invalid ownership ids', () {
      for (final value in <String?>[null, '', 'External', 'unknown']) {
        expect(AudioOwnership.fromId(value), AudioOwnership.external);
      }
    });
  });
}
