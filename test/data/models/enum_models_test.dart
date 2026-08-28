import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/inference_backend.dart';
import 'package:transcriber/data/models/processing_mode.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcription_language.dart';

void main() {
  group('InferenceBackend', () {
    test('exposes stable ids and labels', () {
      expect(
        InferenceBackend.values.map((backend) => (backend.id, backend.label)),
        [('auto', 'Auto'), ('gpu', 'GPU'), ('cpu', 'CPU'), ('npu', 'NPU')],
      );
    });

    test('resolves every persisted id', () {
      for (final backend in InferenceBackend.values) {
        expect(InferenceBackend.fromId(backend.id), backend);
      }
    });

    test('falls back to auto for missing, empty, or unknown ids', () {
      expect(InferenceBackend.fromId(null), InferenceBackend.auto);
      expect(InferenceBackend.fromId(''), InferenceBackend.auto);
      expect(InferenceBackend.fromId('GPU'), InferenceBackend.auto);
      expect(InferenceBackend.fromId('unknown'), InferenceBackend.auto);
    });
  });

  group('ProcessingMode', () {
    test('exposes mutually exclusive local and cloud states', () {
      expect(ProcessingMode.onDevice.id, 'local');
      expect(ProcessingMode.onDevice.isLocal, isTrue);
      expect(ProcessingMode.onDevice.isCloud, isFalse);
      expect(ProcessingMode.cloud.id, 'remote');
      expect(ProcessingMode.cloud.isLocal, isFalse);
      expect(ProcessingMode.cloud.isCloud, isTrue);
    });

    test('uses cloud only for the exact persisted remote id', () {
      expect(ProcessingMode.fromId('remote'), ProcessingMode.cloud);
      for (final value in <String?>[null, '', 'local', 'REMOTE', 'unknown']) {
        expect(ProcessingMode.fromId(value), ProcessingMode.onDevice);
      }
    });
  });

  group('RemoteProviderId', () {
    test('round-trips every stable provider id', () {
      expect(RemoteProviderId.values.map((provider) => provider.id), [
        'anthropic',
        'openai',
        'google',
        'openrouter',
      ]);
      for (final provider in RemoteProviderId.values) {
        expect(RemoteProviderId.fromId(provider.id), provider);
      }
    });

    test('falls back to Anthropic for invalid provider ids', () {
      for (final value in <String?>[null, '', 'OpenAI', 'unknown']) {
        expect(RemoteProviderId.fromId(value), RemoteProviderId.anthropic);
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
}
