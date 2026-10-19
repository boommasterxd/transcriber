import 'gemini_model_catalog.dart';
import 'provider_model_capabilities.dart';
import 'remote_model_info.dart';

/// One provider listing, shared by the locally filtered model pickers.
class ProviderModelCatalog {
  ProviderModelCatalog.openAi(Iterable<Map> models)
    : _models = List.unmodifiable(models),
      _isGoogle = false;

  ProviderModelCatalog.google(Iterable<Map> models)
    : _models = List.unmodifiable(models),
      _isGoogle = true;

  final List<Map> _models;
  final bool _isGoogle;

  List<RemoteModelInfo> modelsFor({required bool forTranscription}) {
    final result = <String, RemoteModelInfo>{};
    for (final raw in _models) {
      final model = _isGoogle
          ? geminiCatalogModel(raw, forTranscription: forTranscription)
          : _openAiModel(raw, forTranscription);
      if (model != null) result.putIfAbsent(model.id, () => model);
    }
    return result.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
  }

  RemoteModelInfo? _openAiModel(Map raw, bool forTranscription) {
    final id = raw['id'];
    if (id is! String) return null;
    final supported = forTranscription
        ? ProviderModelCapabilities.isOpenAiTranscriptionModel(id)
        : ProviderModelCapabilities.isOpenAiSummaryModel(id);
    return supported ? RemoteModelInfo(id: id) : null;
  }
}
