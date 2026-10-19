import 'remote_api_client.dart';

/// Applies the shared task filter to a provider's raw model catalog.
mixin ModelCatalogListing implements ModelCatalogClient {
  @override
  Future<List<RemoteModelInfo>> listModels({
    required bool forTranscription,
  }) async =>
      (await loadModelCatalog()).modelsFor(forTranscription: forTranscription);
}
