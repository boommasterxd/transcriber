import '../../data/models/transcription_result.dart';
import 'provider_model_catalog.dart';
import 'remote_model_info.dart';

export 'provider_model_catalog.dart';
export 'remote_model_info.dart';

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
  Future<ProviderModelCatalog> loadModelCatalog();

  Future<List<RemoteModelInfo>> listModels({required bool forTranscription});
}

/// Convenience composition used by the provider factory and settings UI.
abstract interface class RemoteProviderClient
    implements
        TranscriptionProviderClient,
        SummaryProviderClient,
        ProviderCredentialClient,
        ModelCatalogClient {
  /// Releases client-owned resources. Injected transports remain caller-owned.
  void close();
}
