import 'dart:async';

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

const _catalogFreshness = Duration(minutes: 5);
const _catalogRetention = Duration(minutes: 15);

/// One compact listing per provider and active credential revision.
final _remoteModelCatalogProvider = FutureProvider.autoDispose
    .family<_CatalogSnapshot?, RemoteProviderId>(
      _loadCatalog,
      retry: (_, _) => null,
    );

Future<_CatalogSnapshot?> _loadCatalog(
  Ref ref,
  RemoteProviderId provider,
) async {
  final controller = ref.watch(connectionsControllerProvider.notifier);
  final (connected, _) = ref.watch(
    connectionsControllerProvider.select(
      (connections) => (
        connections[provider] ?? false,
        controller.catalogRevision(provider),
      ),
    ),
  );
  if (!connected) return null;

  var disposed = false;
  RemoteProviderClient? pendingClient;
  ref.onDispose(() {
    disposed = true;
    pendingClient?.close();
  });

  final key = await controller.apiKey(provider);
  if (disposed || key.isEmpty) return null;
  final client = RemoteClientFactory.create(provider, key);
  pendingClient = client;
  try {
    final catalog = await client.loadModelCatalog();
    if (disposed) return null;
    final link = ref.keepAlive();
    final expiration = Timer(_catalogRetention, link.close);
    ref.onDispose(expiration.cancel);
    return _CatalogSnapshot(catalog);
  } finally {
    pendingClient = null;
    client.close();
  }
}

/// Revalidates on picker entry or explicit refresh, without starting a second
/// load while a shared request is already pending.
bool refreshRemoteModelCatalog(
  ProviderContainer container,
  RemoteProviderId provider, {
  bool force = false,
}) {
  if (!(container.read(connectionsControllerProvider)[provider] ?? false)) {
    return false;
  }
  final query = _remoteModelCatalogProvider(provider);
  if (!container.read(query.exists)) return false;
  final catalog = container.read(query);
  if (catalog.isLoading) return false;
  if (!force && !catalog.hasError && catalog.value?.isStale == false) {
    return false;
  }
  container.invalidate(query, asReload: true);
  return true;
}

/// Projects a preclassified list from the shared listing for one model picker.
final remoteModelsProvider = FutureProvider.autoDispose
    .family<List<RemoteModelInfo>, RemoteModelsQuery>((ref, query) {
      final provider = _remoteModelCatalogProvider(query.provider);
      final catalog = ref.watch(provider);
      if (catalog.isLoading) {
        return ref
            .watch(provider.future)
            .then((snapshot) => _modelsFor(snapshot, query));
      }
      if (catalog.hasError) {
        Error.throwWithStackTrace(catalog.error!, catalog.stackTrace!);
      }
      return _modelsFor(catalog.requireValue, query);
    }, retry: (_, _) => null);

List<RemoteModelInfo> _modelsFor(
  _CatalogSnapshot? snapshot,
  RemoteModelsQuery query,
) =>
    snapshot?.catalog.modelsFor(forTranscription: query.forTranscription) ??
    const [];

class _CatalogSnapshot {
  _CatalogSnapshot(this.catalog);

  final ProviderModelCatalog catalog;
  final _loadedAt = DateTime.now();

  bool get isStale {
    final age = DateTime.now().difference(_loadedAt);
    return age.isNegative || age >= _catalogFreshness;
  }
}
