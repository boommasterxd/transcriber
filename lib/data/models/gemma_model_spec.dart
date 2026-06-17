import 'model_badge.dart';

/// A locally runnable text/multimodal model from the `flutter_gemma` package.
///
/// [modelTypeId] maps to flutter_gemma's `ModelType` (resolved in
/// [GemmaEngine]); [downloadUrl] is the LiteRT/`.task` artifact on Hugging Face.
class GemmaModelSpec {
  const GemmaModelSpec({
    required this.id,
    required this.displayName,
    required this.sizeBytes,
    required this.badge,
    required this.modelTypeId,
    required this.downloadUrl,
    required this.maxTokens,
    this.supportsAudio = false,
    this.needsHfToken = false,
    this.recommended = false,
  });

  final String id;
  final String displayName;
  final int sizeBytes;
  final ModelBadge badge;

  /// flutter_gemma `ModelType` discriminator: gemmaIt, gemma4, qwen, qwen3,
  /// deepSeek, phi, general.
  final String modelTypeId;

  /// Direct download URL of the LiteRT model artifact.
  final String downloadUrl;

  /// Default context window used when instantiating the model.
  final int maxTokens;

  /// True for Gemma 3n / Gemma 4 models that accept audio input directly and
  /// can therefore also perform on-device transcription.
  final bool supportsAudio;

  /// Whether the download host requires a Hugging Face access token.
  final bool needsHfToken;

  /// Highlighted as the suggested default for non-technical users.
  final bool recommended;

  /// File name used when persisting the model on disk.
  String get fileName => downloadUrl.split('/').last;
}
