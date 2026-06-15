import '../models/gemma_model_spec.dart';
import '../models/model_badge.dart';

/// On-device summary models available through the `flutter_gemma` package.
///
/// Download URLs point at the canonical LiteRT (`.litertlm` / `.task`) artifacts
/// on Hugging Face. Most require a free Hugging Face access token (configured in
/// settings) because the repos are gated. Audio-capable Gemma 3n models can also
/// perform transcription directly.
const int _mb = 1024 * 1024;

class GemmaCatalog {
  const GemmaCatalog._();

  static const List<GemmaModelSpec> models = [
    GemmaModelSpec(
      id: 'gemma3_270m',
      displayName: 'Gemma 3 · 270M',
      sizeBytes: 300 * _mb,
      badge: ModelBadge.veryFast,
      modelTypeId: 'gemmaIt',
      downloadUrl:
          'https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma-3-270m-it-q8.litertlm',
      maxTokens: 2048,
    ),
    GemmaModelSpec(
      id: 'qwen25_05b',
      displayName: 'Qwen 2.5 · 0.5B',
      sizeBytes: 500 * _mb,
      badge: ModelBadge.fast,
      modelTypeId: 'qwen',
      downloadUrl:
          'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.litertlm',
      maxTokens: 2048,
    ),
    GemmaModelSpec(
      id: 'gemma3_1b',
      displayName: 'Gemma 3 · 1B',
      sizeBytes: 530 * _mb,
      badge: ModelBadge.balanced,
      modelTypeId: 'gemmaIt',
      downloadUrl:
          'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm',
      maxTokens: 4096,
    ),
    GemmaModelSpec(
      id: 'qwen25_15b',
      displayName: 'Qwen 2.5 · 1.5B',
      sizeBytes: 1600 * _mb,
      badge: ModelBadge.detailed,
      modelTypeId: 'qwen',
      downloadUrl:
          'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.litertlm',
      maxTokens: 4096,
    ),
    GemmaModelSpec(
      id: 'gemma3n_e2b',
      displayName: 'Gemma 3n · E2B',
      sizeBytes: 3100 * _mb,
      badge: ModelBadge.multimodal,
      modelTypeId: 'gemmaIt',
      downloadUrl:
          'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task',
      maxTokens: 4096,
      supportsAudio: true,
    ),
    GemmaModelSpec(
      id: 'gemma3n_e4b',
      displayName: 'Gemma 3n · E4B',
      sizeBytes: 6500 * _mb,
      badge: ModelBadge.multimodal,
      modelTypeId: 'gemmaIt',
      downloadUrl:
          'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task',
      maxTokens: 4096,
      supportsAudio: true,
    ),
  ];

  static const String defaultId = 'gemma3_1b';

  static GemmaModelSpec byId(String id) =>
      models.firstWhere((m) => m.id == id, orElse: () => models[2]);

  /// Models that can also transcribe audio on-device (multimodal).
  static List<GemmaModelSpec> get audioCapable =>
      models.where((m) => m.supportsAudio).toList();
}
