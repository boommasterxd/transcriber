import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/catalog/whisper_catalog.dart';
import 'package:transcriber/data/models/model_badge.dart';

void main() {
  group('WhisperCatalog', () {
    test('exposes models in increasing capability and size order', () {
      expect(WhisperCatalog.models.map((model) => model.id), [
        'tiny',
        'base',
        'small',
        'medium',
      ]);
      expect(WhisperCatalog.models.map((model) => model.displayName), [
        'Whisper Tiny',
        'Whisper Base',
        'Whisper Small',
        'Whisper Medium',
      ]);
      expect(WhisperCatalog.models.map((model) => model.sizeBytes), [
        75 * 1024 * 1024,
        142 * 1024 * 1024,
        466 * 1024 * 1024,
        1500 * 1024 * 1024,
      ]);
      expect(WhisperCatalog.models.map((model) => model.badge), [
        ModelBadge.veryFast,
        ModelBadge.recommended,
        ModelBadge.balanced,
        ModelBadge.accurate,
      ]);
    });

    test('resolves every model by its stable id', () {
      for (final model in WhisperCatalog.models) {
        expect(WhisperCatalog.byId(model.id), same(model));
      }
    });

    test('uses the uniquely recommended base model as default', () {
      final recommended = WhisperCatalog.models.where(
        (model) => model.recommended,
      );

      expect(WhisperCatalog.defaultId, 'base');
      expect(recommended, hasLength(1));
      expect(recommended.single, same(WhisperCatalog.byId('base')));
      expect(WhisperCatalog.byId('unknown'), same(recommended.single));
      expect(WhisperCatalog.byId(''), same(recommended.single));
    });
  });
}
