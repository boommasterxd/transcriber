import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/remote/anthropic_client.dart';
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/remote/openai_client.dart';
import 'package:transcriber/services/remote/remote_client_factory.dart';

void main() {
  test('creates the provider-specific client and retains its API key', () {
    final clients = {
      RemoteProviderId.anthropic: RemoteClientFactory.create(
        RemoteProviderId.anthropic,
        'anthropic-key',
      ),
      RemoteProviderId.openai: RemoteClientFactory.create(
        RemoteProviderId.openai,
        'openai-key',
      ),
      RemoteProviderId.google: RemoteClientFactory.create(
        RemoteProviderId.google,
        'google-key',
      ),
      RemoteProviderId.openrouter: RemoteClientFactory.create(
        RemoteProviderId.openrouter,
        'openrouter-key',
      ),
    };

    expect(clients[RemoteProviderId.anthropic], isA<AnthropicClient>());
    expect(clients[RemoteProviderId.openai], isA<OpenAiClient>());
    expect(clients[RemoteProviderId.google], isA<GoogleClient>());
    expect(clients[RemoteProviderId.openrouter], isA<OpenRouterClient>());
    expect(
      (clients[RemoteProviderId.anthropic]! as AnthropicClient).apiKey,
      'anthropic-key',
    );
    expect(
      (clients[RemoteProviderId.openai]! as OpenAiClient).apiKey,
      'openai-key',
    );
    expect(
      (clients[RemoteProviderId.google]! as GoogleClient).apiKey,
      'google-key',
    );
    expect(
      (clients[RemoteProviderId.openrouter]! as OpenRouterClient).apiKey,
      'openrouter-key',
    );
  });
}
