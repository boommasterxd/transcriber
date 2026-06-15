import '../../data/models/remote_provider.dart';
import 'anthropic_client.dart';
import 'google_client.dart';
import 'openai_client.dart';
import 'remote_api_client.dart';

/// Creates the right [RemoteApiClient] for a provider + key.
class RemoteClientFactory {
  const RemoteClientFactory._();

  static RemoteApiClient create(RemoteProviderId provider, String apiKey) {
    switch (provider) {
      case RemoteProviderId.anthropic:
        return AnthropicClient(apiKey: apiKey);
      case RemoteProviderId.openai:
        return OpenAiClient(apiKey: apiKey);
      case RemoteProviderId.google:
        return GoogleClient(apiKey: apiKey);
      case RemoteProviderId.openrouter:
        return OpenRouterClient(apiKey: apiKey);
    }
  }
}
