import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/catalog/remote_catalog.dart';
import 'package:transcriber/data/models/remote_provider.dart';

void main() {
  group('RemoteCatalog providers', () {
    test('contains metadata for every provider exactly once', () {
      expect(
        RemoteCatalog.providers.map((provider) => provider.id).toSet(),
        RemoteProviderId.values.toSet(),
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
        RemoteProviderId.anthropic: ('Anthropic', const Color(0xFFCC785C), 'A'),
        RemoteProviderId.openai: ('OpenAI', const Color(0xFF10A37F), 'O'),
        RemoteProviderId.google: ('Google', const Color(0xFF4285F4), 'G'),
        RemoteProviderId.openrouter: (
          'OpenRouter',
          const Color(0xFF6566F1),
          'OR',
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

    test('limits native ASR capability to OpenAI and Google', () {
      expect(RemoteCatalog.asrProviders, [
        RemoteProviderId.openai,
        RemoteProviderId.google,
      ]);
      expect(RemoteCatalog.asrProviders.toSet(), hasLength(2));
    });
  });

  group('RemoteCatalog defaults', () {
    test('returns a chat default for every provider', () {
      expect(
        {
          for (final provider in RemoteProviderId.values)
            provider: RemoteCatalog.chatDefault(provider),
        },
        {
          RemoteProviderId.anthropic: 'claude-sonnet-4-6',
          RemoteProviderId.openai: 'gpt-5.5',
          RemoteProviderId.google: 'gemini-3.5-flash',
          RemoteProviderId.openrouter: 'openrouter/auto',
        },
      );
    });

    test('returns provider defaults or a safe fallback for ASR', () {
      expect(
        RemoteCatalog.asrDefault(RemoteProviderId.openai),
        'gpt-4o-transcribe',
      );
      expect(
        RemoteCatalog.asrDefault(RemoteProviderId.google),
        'gemini-3.5-flash',
      );
      expect(
        RemoteCatalog.asrDefault(RemoteProviderId.anthropic),
        'gpt-4o-transcribe',
      );
      expect(
        RemoteCatalog.asrDefault(RemoteProviderId.openrouter),
        'gpt-4o-transcribe',
      );
    });

    test('provides an HTTPS API-key page for every provider', () {
      for (final provider in RemoteProviderId.values) {
        final url = RemoteCatalog.keyUrlFor(provider);
        expect(url, RemoteCatalog.keyUrl[provider]);
        expect(Uri.parse(url).isScheme('https'), isTrue);
      }
    });
  });
}
