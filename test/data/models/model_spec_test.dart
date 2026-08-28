import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/gemma_model_spec.dart';
import 'package:transcriber/data/models/model_badge.dart';
import 'package:transcriber/data/models/whisper_model_spec.dart';

void main() {
  _testGemmaModelSpec();
  _testWhisperModelSpec();
  _testModelBadges();
}

void _testGemmaModelSpec() {
  group('GemmaModelSpec', () {
    test('uses safe optional capability defaults', () {
      const spec = GemmaModelSpec(
        id: 'model',
        displayName: 'Model',
        sizeBytes: 1,
        badge: ModelBadge.fast,
        modelTypeId: 'general',
        downloadUrl: 'https://example.test/models/model.task',
        maxTokens: 128,
      );

      expect(spec.supportsAudio, isFalse);
      expect(spec.needsHfToken, isFalse);
      expect(spec.recommended, isFalse);
      expect(spec.fileName, 'model.task');
    });

    test('preserves explicitly enabled capabilities', () {
      const spec = GemmaModelSpec(
        id: 'audio-model',
        displayName: 'Audio Model',
        sizeBytes: 2048,
        badge: ModelBadge.multimodal,
        modelTypeId: 'gemma4',
        downloadUrl: 'model.litertlm',
        maxTokens: 4096,
        supportsAudio: true,
        needsHfToken: true,
        recommended: true,
      );

      expect(spec.supportsAudio, isTrue);
      expect(spec.needsHfToken, isTrue);
      expect(spec.recommended, isTrue);
      expect(spec.fileName, 'model.litertlm');
    });

    test('derives an empty file name from a trailing slash', () {
      const spec = GemmaModelSpec(
        id: 'directory',
        displayName: 'Directory',
        sizeBytes: 0,
        badge: ModelBadge.openSource,
        modelTypeId: 'general',
        downloadUrl: 'https://example.test/models/',
        maxTokens: 0,
      );

      expect(spec.fileName, isEmpty);
    });
  });
}

void _testWhisperModelSpec() {
  group('WhisperModelSpec', () {
    test('defaults to not recommended', () {
      const spec = WhisperModelSpec(
        id: 'tiny',
        displayName: 'Tiny',
        sizeBytes: 1,
        badge: ModelBadge.veryFast,
      );

      expect(spec.recommended, isFalse);
    });

    test('preserves recommendation metadata', () {
      const spec = WhisperModelSpec(
        id: 'base',
        displayName: 'Base',
        sizeBytes: 2,
        badge: ModelBadge.recommended,
        recommended: true,
      );

      expect(spec.recommended, isTrue);
      expect(spec.badge, ModelBadge.recommended);
    });
  });
}

void _testModelBadges() {
  group('ModelBadge', () {
    for (final language in AppLanguage.values) {
      test('maps every localized badge in ${language.code}', () {
        _expectLocalizedBadgeLabels(AppStrings.of(language));
      });
    }

    test('uses fixed labels for capability badges', () {
      final strings = AppStrings.of(AppLanguage.en);

      expect(ModelBadge.multimodal.label(strings), 'Multimodal · Audio');
      expect(ModelBadge.openSource.label(strings), 'Open Source');
    });
  });
}

void _expectLocalizedBadgeLabels(AppStrings strings) {
  final expectedLabels = {
    ModelBadge.veryFast: strings.badgeVeryFast,
    ModelBadge.fast: strings.badgeFast,
    ModelBadge.balanced: strings.badgeBalanced,
    ModelBadge.accurate: strings.badgeAccurate,
    ModelBadge.detailed: strings.badgeDetailed,
    ModelBadge.recommended: strings.recommended,
    ModelBadge.mostCapable: strings.badgeMostCapable,
    ModelBadge.cheap: strings.badgeCheap,
    ModelBadge.reasoning: strings.badgeReasoning,
  };

  for (final entry in expectedLabels.entries) {
    expect(entry.key.label(strings), entry.value);
  }
}
