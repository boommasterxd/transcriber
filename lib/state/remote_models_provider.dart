import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/remote_provider.dart';
import '../services/remote/remote_api_client.dart';
import '../services/remote/remote_client_factory.dart';
import 'connections_controller.dart';

/// Identifies which provider + stage a model list is for.
typedef RemoteModelsQuery = ({
  RemoteProviderId provider,
  bool forTranscription,
});

/// Keeps one raw listing per provider and credential revision, without keys in
/// provider identities or cached catalog values.
final remoteModelCatalogProvider =
    FutureProvider.family<ProviderModelCatalog?, RemoteProviderId>(
      retry: (_, _) => null,
      (ref, provider) async {
        final controller = ref.watch(connectionsControllerProvider.notifier);
        ref.watch(
          connectionsControllerProvider.select(
            (connections) => (
              connections[provider] ?? false,
              controller.catalogRevision(provider),
            ),
          ),
        );
        final key = await controller.apiKey(provider);
        if (!ref.mounted || key.isEmpty) return null;
        final client = RemoteClientFactory.create(provider, key);
        ref.onDispose(client.close);
        try {
          return await client.loadModelCatalog();
        } finally {
          client.close();
        }
      },
    );

/// Locally filters the shared listing for one model picker.
final remoteModelsProvider =
    FutureProvider.family<List<RemoteModelInfo>, RemoteModelsQuery>(
      retry: (_, _) => null,
      (ref, query) async {
        final catalog = await ref.watch(
          remoteModelCatalogProvider(query.provider).future,
        );
        return catalog?.modelsFor(forTranscription: query.forTranscription) ??
            const [];
      },
    );
