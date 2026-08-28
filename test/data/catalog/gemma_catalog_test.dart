import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/catalog/gemma_catalog.dart';
import 'package:transcriber/data/models/model_badge.dart';

void main() {
  group('GemmaCatalog', () {
    test('contains unique, alphabetically sorted model metadata', () {
      final models = GemmaCatalog.models;
      final names = models.map((model) => model.displayName).toList();
      final sortedNames = List.of(names)
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      expect(models, hasLength(7));
      expect(names, sortedNames);
      expect(models.map((model) => model.id).toSet(), hasLength(models.length));
      expect(
        models.every((model) => model.sizeBytes > 0 && model.maxTokens > 0),
        isTrue,
      );
      expect(
        models.every(
          (model) =>
              Uri.parse(model.downloadUrl).isScheme('https') &&
              model.fileName.isNotEmpty,
        ),
        isTrue,
      );
    });

    test('resolves every model by its stable id', () {
      for (final model in GemmaCatalog.models) {
        expect(GemmaCatalog.byId(model.id), same(model));
      }
    });

    test('falls back to the recommended default for unknown ids', () {
      final defaultModel = GemmaCatalog.byId(GemmaCatalog.defaultId);

      expect(defaultModel.id, 'qwen3_06b');
      expect(defaultModel.recommended, isTrue);
      expect(defaultModel.badge, ModelBadge.recommended);
      expect(GemmaCatalog.byId(''), same(defaultModel));
      expect(GemmaCatalog.byId('unknown'), same(defaultModel));
    });

    test('returns only the two audio-capable multimodal models', () {
      final audioModels = GemmaCatalog.audioCapable;

      expect(audioModels.map((model) => model.id), [
        'gemma4_e2b',
        'gemma4_e4b',
      ]);
      expect(audioModels.every((model) => model.supportsAudio), isTrue);
      expect(
        audioModels.every((model) => model.badge == ModelBadge.multimodal),
        isTrue,
      );
      expect(audioModels, isNot(same(GemmaCatalog.models)));
    });

    test('does not require gated access tokens for catalog downloads', () {
      expect(GemmaCatalog.models.every((model) => !model.needsHfToken), isTrue);
    });

    test('covers the intended model type and badge classifications', () {
      expect(GemmaCatalog.models.map((model) => model.modelTypeId).toSet(), {
        'qwen',
        'qwen3',
        'deepSeek',
        'gemma4',
        'general',
      });
      expect(GemmaCatalog.models.map((model) => model.badge).toSet(), {
        ModelBadge.fast,
        ModelBadge.recommended,
        ModelBadge.detailed,
        ModelBadge.reasoning,
        ModelBadge.multimodal,
      });
    });
  });
}
