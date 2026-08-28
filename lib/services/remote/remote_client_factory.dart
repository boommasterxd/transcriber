import '../../data/models/remote_provider.dart';
import 'google_client.dart';
import 'openai_client.dart';
import 'remote_api_client.dart';

/// Creates the right provider client for a provider and BYOK key.
class RemoteClientFactory {
  const RemoteClientFactory._();

  static RemoteProviderClient create(RemoteProviderId provider, String apiKey) {
    switch (provider) {
      case RemoteProviderId.openai:
        return OpenAiClient(apiKey: apiKey);
      case RemoteProviderId.google:
        return GoogleClient(apiKey: apiKey);
    }
  }
}
