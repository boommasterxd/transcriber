import '../../data/models/transcription_result.dart';

/// A model exposed by a provider's model catalog.
class RemoteModelInfo {
  const RemoteModelInfo({required this.id, this.label});

  final String id;
  final String? label;

  String get display => label?.isNotEmpty == true ? label! : id;
}

/// Provider boundary for audio transcription.
abstract interface class TranscriptionProviderClient {
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    required String modelId,
    String? languageCode,
  });
}

/// Provider boundary for transcript summarization.
abstract interface class SummaryProviderClient {
  Future<String> summarize({
    required String systemPrompt,
    required String userPrompt,
    required String modelId,
  });
}

/// Provider boundary for validating a BYOK credential.
abstract interface class ProviderCredentialClient {
  Future<void> testConnection();
}

/// Provider boundary for the model picker in settings.
abstract interface class ModelCatalogClient {
  Future<List<RemoteModelInfo>> listModels({required bool forTranscription});
}

/// Convenience composition used by the provider factory and settings UI.
abstract interface class RemoteProviderClient
    implements
        TranscriptionProviderClient,
        SummaryProviderClient,
        ProviderCredentialClient,
        ModelCatalogClient {}
