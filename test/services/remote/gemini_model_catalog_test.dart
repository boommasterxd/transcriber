import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/remote/gemini_model_catalog.dart';

void main() {
  test(
    'retains a valid provider name and label without inventing metadata',
    () {
      final model = geminiCatalogModel(
        _entry(displayName: 'Next Generation'),
        forTranscription: false,
      );
      expect(model?.id, 'gemini-future');
      expect(model?.label, 'Next Generation');
    },
  );
  test('accepts a safe unprefixed model name and absent optional label', () {
    final model = geminiCatalogModel(
      _entry(name: 'new-text-family'),
      forTranscription: false,
    );
    expect(model?.id, 'new-text-family');
    expect(model?.label, isNull);
  });
  for (final field in ['name', 'displayName', 'description']) {
    for (final value in [42, {}, [], true]) {
      test('skips malformed $field metadata $value', () {
        final raw = _entry()..[field] = value;
        expect(geminiCatalogModel(raw, forTranscription: true), isNull);
      });
    }
  }
  for (final methods in [
    'generateContent',
    {},
    [42],
    ['generateContent', false],
  ]) {
    test('skips malformed generation methods $methods', () {
      expect(
        geminiCatalogModel(_entry(methods: methods), forTranscription: false),
        isNull,
      );
    });
  }
  for (final methods in [
    null,
    [],
    ['embedContent'],
  ]) {
    test('requires generation support for a generic model $methods', () {
      expect(
        geminiCatalogModel(_entry(methods: methods), forTranscription: true),
        isNull,
      );
    });
  }
  test('keeps unary ASR available without generation methods', () {
    expect(
      geminiCatalogModel(
        _entry(name: 'models/gemini-99-asr', methods: null),
        forTranscription: true,
      )?.id,
      'gemini-99-asr',
    );
  });
  for (final field in ['displayName', 'description']) {
    test('rejects oversized $field metadata rather than truncating hints', () {
      final raw = _entry()..[field] = 'x' * 8193;
      expect(geminiCatalogModel(raw, forTranscription: false), isNull);
    });
  }
  test('metadata roles override otherwise generic IDs', () {
    expect(
      geminiCatalogModel(
        _entry(description: 'Image generation model'),
        forTranscription: false,
      ),
      isNull,
    );
  });
}

Map<String, Object?> _entry({
  String name = 'models/gemini-future',
  Object? displayName,
  Object? description,
  Object? methods = const ['generateContent'],
}) => {
  'name': name,
  'displayName': displayName,
  'description': description,
  'supportedGenerationMethods': methods,
};
