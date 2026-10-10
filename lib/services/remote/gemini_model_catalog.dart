import 'provider_model_capabilities.dart';
import 'remote_api_client.dart';

/// Parses only documented Gemini fields and filters purpose hints conservatively.
RemoteModelInfo? geminiCatalogModel(Map raw, {required bool forTranscription}) {
  final name = raw['name'];
  final label = raw['displayName'];
  final description = raw['description'];
  if (name is! String ||
      !_validOptionalText(label, 128) ||
      !_validOptionalText(description, 8192)) {
    return null;
  }
  final methods = _generationMethods(raw['supportedGenerationMethods']);
  if (methods == null) return null;
  final id = name.startsWith('models/') ? name.substring(7) : name;
  final classify = forTranscription
      ? ProviderModelCapabilities.isGeminiTranscriptionModel
      : ProviderModelCapabilities.isGeminiSummaryModel;
  if (!classify(
    id,
    methods,
    displayName: label as String?,
    description: description as String?,
  )) {
    return null;
  }
  return RemoteModelInfo(id: id, label: label);
}

Set<String>? _generationMethods(Object? raw) {
  if (raw == null) return const {};
  if (raw is! List || !raw.every((method) => method is String)) return null;
  return raw.cast<String>().toSet();
}

bool _validOptionalText(Object? value, int maximumLength) =>
    value == null || (value is String && value.length <= maximumLength);
