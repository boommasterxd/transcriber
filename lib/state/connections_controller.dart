import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/remote_provider.dart';
import 'providers.dart';

/// Tracks which cloud providers have an API key stored (connected), and manages
/// connect / disconnect. Keys live in secure storage via [SettingsRepository].
class ConnectionsController extends Notifier<Map<RemoteProviderId, bool>> {
  @override
  Map<RemoteProviderId, bool> build() =>
      Map.of(ref.watch(initialConnectionsProvider));

  bool isConnected(RemoteProviderId provider) => state[provider] ?? false;

  Future<void> connect(RemoteProviderId provider, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('API key must not be empty');
    }
    await ref.read(providerCredentialTesterProvider)(provider, trimmed);
    await ref.read(settingsRepositoryProvider).setApiKey(provider, trimmed);
    state = {...state, provider: true};
  }

  Future<void> test(RemoteProviderId provider) async {
    final key = await apiKey(provider);
    if (key.isEmpty) {
      throw StateError('No API key is stored for this provider');
    }
    await ref.read(providerCredentialTesterProvider)(provider, key);
  }

  Future<void> disconnect(RemoteProviderId provider) async {
    await ref.read(settingsRepositoryProvider).deleteApiKey(provider);
    state = {...state, provider: false};
  }

  Future<String> apiKey(RemoteProviderId provider) async =>
      await ref.read(settingsRepositoryProvider).apiKey(provider) ?? '';
}

final connectionsControllerProvider =
    NotifierProvider<ConnectionsController, Map<RemoteProviderId, bool>>(
      ConnectionsController.new,
    );
