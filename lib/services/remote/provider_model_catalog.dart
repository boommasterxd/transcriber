import 'gemini_model_catalog.dart';
import 'provider_model_capabilities.dart';
import 'remote_model_info.dart';

/// One provider listing, shared by the locally filtered model pickers.
class ProviderModelCatalog {
  ProviderModelCatalog._(_CatalogModels models)
    : _transcription = _sortedModels(models.transcription),
      _summaries = _sortedModels(models.summaries);

  factory ProviderModelCatalog.openAi(Iterable<Map> rows) {
    final models = _CatalogModels();
    for (final row in rows) {
      final id = row['id'];
      if (id is! String) continue;
      final transcription =
          ProviderModelCapabilities.isOpenAiTranscriptionModel(id);
      final summary = ProviderModelCapabilities.isOpenAiSummaryModel(id);
      if (!transcription && !summary) continue;
      final model = RemoteModelInfo(id: id);
      models.add(transcription ? model : null, summary ? model : null);
    }
    return ProviderModelCatalog._(models);
  }

  static Future<ProviderModelCatalog> loadGooglePages(
    Stream<Iterable<Map>> pages,
  ) async {
    final models = _CatalogModels();
    await for (final rows in pages) {
      for (final row in rows) {
        final transcription = geminiCatalogModel(row, forTranscription: true);
        final summary = geminiCatalogModel(row, forTranscription: false);
        models.add(
          transcription,
          summary == null ? null : transcription ?? summary,
        );
      }
    }
    return ProviderModelCatalog._(models);
  }

  final List<RemoteModelInfo> _transcription;
  final List<RemoteModelInfo> _summaries;

  List<RemoteModelInfo> modelsFor({required bool forTranscription}) =>
      forTranscription ? _transcription : _summaries;

  static List<RemoteModelInfo> _sortedModels(
    Map<String, RemoteModelInfo> models,
  ) => List.unmodifiable(
    models.values.toList()..sort((left, right) => left.id.compareTo(right.id)),
  );
}

class _CatalogModels {
  final transcription = <String, RemoteModelInfo>{};
  final summaries = <String, RemoteModelInfo>{};

  void add(RemoteModelInfo? asrModel, RemoteModelInfo? summaryModel) {
    if (asrModel != null) {
      transcription.putIfAbsent(asrModel.id, () => asrModel);
    }
    if (summaryModel != null) {
      summaries.putIfAbsent(summaryModel.id, () => summaryModel);
    }
  }
}
