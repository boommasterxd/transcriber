import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/catalog/remote_catalog.dart';
import 'package:transcriber/data/models/remote_provider.dart';

void main() {
  group('RemoteCatalog providers', () {
    test('contains only OpenAI and Google provider metadata', () {
      expect(
        RemoteCatalog.providers.map((provider) => provider.id),
        RemoteProviderId.values,
      );
      expect(
        RemoteCatalog.providers.map((provider) => provider.id).toSet(),
        hasLength(RemoteCatalog.providers.length),
      );
      expect(
        RemoteCatalog.providers.every(
          (provider) =>
              provider.name.isNotEmpty &&
              provider.glyph.isNotEmpty &&
              provider.sub.isNotEmpty,
        ),
        isTrue,
      );
    });

    test('resolves each provider and preserves its display metadata', () {
      final expected = {
        RemoteProviderId.openai: ('OpenAI', const Color(0xFF10A37F), 'O'),
        RemoteProviderId.google: (
          'Google Gemini',
          const Color(0xFF4285F4),
          'G',
        ),
      };

      for (final entry in expected.entries) {
        final provider = RemoteCatalog.provider(entry.key);
        expect(provider.id, entry.key);
        expect(provider.name, entry.value.$1);
        expect(provider.color, entry.value.$2);
        expect(provider.glyph, entry.value.$3);
      }
    });

    test('supports native ASR on both cloud providers', () {
      expect(RemoteCatalog.asrProviders, RemoteProviderId.values);
      expect(RemoteCatalog.asrProviders.toSet(), hasLength(2));
    });
  });

  group('RemoteCatalog defaults', () {
    test('returns the documented chat default for every provider', () {
      expect(
        {
          for (final provider in RemoteProviderId.values)
            provider: RemoteCatalog.chatDefault(provider),
        },
        {
          RemoteProviderId.openai: 'gpt-5.6-luna',
          RemoteProviderId.google: 'gemini-3.7-flash',
        },
      );
    });

    test('returns the documented ASR default for every provider', () {
      expect(
        {
          for (final provider in RemoteProviderId.values)
            provider: RemoteCatalog.asrDefault(provider),
        },
        {
          RemoteProviderId.openai: 'gpt-transcribe',
          RemoteProviderId.google: 'gemini-3.5-transcribe',
        },
      );
    });

    test('provides an HTTPS API-key page for every provider', () {
      expect(RemoteCatalog.keyUrl, {
        RemoteProviderId.openai: 'https://platform.openai.com/api-keys',
        RemoteProviderId.google: 'https://aistudio.google.com/app/apikey',
      });

      for (final provider in RemoteProviderId.values) {
        final url = RemoteCatalog.keyUrlFor(provider);
        expect(url, RemoteCatalog.keyUrl[provider]);
        expect(Uri.parse(url).isScheme('https'), isTrue);
      }
    });
  });
}
