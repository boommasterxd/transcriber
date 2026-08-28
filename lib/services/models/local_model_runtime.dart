import '../../data/catalog/gemma_catalog.dart';
import '../summarization/gemma_engine.dart';
import '../transcription/whisper_engine.dart';

typedef ModelDownloadProgress = void Function(double progress);

/// Boundary for installing and inspecting the application's local AI models.
abstract interface class LocalModelRuntime {
  Future<bool> isWhisperDownloaded(String modelId);

  Future<void> downloadWhisper(
    String modelId, {
    ModelDownloadProgress? onProgress,
  });

  Future<void> deleteWhisper(String modelId);

  Future<bool> isGemmaDownloaded(String modelId);

  Future<void> downloadGemma(
    String modelId, {
    String? hfToken,
    ModelDownloadProgress? onProgress,
  });

  Future<void> deleteGemma(String modelId);
}

/// Production adapter that keeps engine-specific model lookup out of state.
class EngineLocalModelRuntime implements LocalModelRuntime {
  EngineLocalModelRuntime({WhisperEngine? whisper, GemmaEngine? gemma})
    : _whisper = whisper ?? WhisperEngine.instance,
      _gemma = gemma ?? GemmaEngine.instance;

  final WhisperEngine _whisper;
  final GemmaEngine _gemma;

  @override
  Future<bool> isWhisperDownloaded(String modelId) =>
      _whisper.isDownloaded(modelId);

  @override
  Future<void> downloadWhisper(
    String modelId, {
    ModelDownloadProgress? onProgress,
  }) => _whisper.download(modelId, onProgress: onProgress);

  @override
  Future<void> deleteWhisper(String modelId) =>
      _whisper.deleteDownload(modelId);

  @override
  Future<bool> isGemmaDownloaded(String modelId) =>
      _gemma.isDownloaded(GemmaCatalog.byId(modelId));

  @override
  Future<void> downloadGemma(
    String modelId, {
    String? hfToken,
    ModelDownloadProgress? onProgress,
  }) => _gemma.download(
    GemmaCatalog.byId(modelId),
    hfToken: hfToken,
    onProgress: onProgress,
  );

  @override
  Future<void> deleteGemma(String modelId) =>
      _gemma.deleteDownload(GemmaCatalog.byId(modelId));
}
