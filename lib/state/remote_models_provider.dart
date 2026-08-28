import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog/remote_catalog.dart';
import '../data/models/remote_provider.dart';
import '../services/remote/remote_api_client.dart';
import '../services/remote/remote_client_factory.dart';
import 'connections_controller.dart';

/// Identifies which provider + stage a model list is for.
typedef RemoteModelsQuery = ({
  RemoteProviderId provider,
  bool forTranscription,
});

/// Fetches the live model list for a provider from its API (requires a stored
/// key). Re-runs when the provider's connection changes.
final remoteModelsProvider =
    FutureProvider.family<List<RemoteModelInfo>, RemoteModelsQuery>((
      ref,
      query,
    ) async {
      ref.watch(connectionsControllerProvider);
      final key = await ref
          .read(connectionsControllerProvider.notifier)
          .apiKey(query.provider);
      if (key.isEmpty) return const [];
      final client = RemoteClientFactory.create(query.provider, key);
      final models = await client.listModels(
        forTranscription: query.forTranscription,
      );
      final defaultId = query.forTranscription
          ? RemoteCatalog.asrDefault(query.provider)
          : RemoteCatalog.chatDefault(query.provider);
      if (models.any((model) => model.id == defaultId)) return models;
      return [RemoteModelInfo(id: defaultId), ...models];
    });
