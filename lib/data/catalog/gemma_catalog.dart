import '../models/gemma_model_spec.dart';
import '../models/model_badge.dart';

/// On-device summary models available through the `flutter_gemma` package.
///
/// This mirrors flutter_gemma's supported text/multimodal LLMs. Vision-only
/// (FastVLM) and embedding models are intentionally excluded since they can't
/// produce text summaries. Audio-capable Gemma 3n / Gemma 4 models can also
/// transcribe.
///
/// Download URLs point at the canonical LiteRT (`.litertlm`) / MediaPipe
/// (`.task`) artifacts on Hugging Face. Several repos are gated and require a
/// free Hugging Face token (configured in settings). Keep these in one place so
/// they're easy to update if an upstream path changes.
const int _mb = 1024 * 1024;

class GemmaCatalog {
  const GemmaCatalog._();

  static const List<GemmaModelSpec> models = [
    GemmaModelSpec(
      id: 'smollm_135m',
      displayName: 'SmolLM 135M',
      sizeBytes: 135 * _mb,
      badge: ModelBadge.veryFast,
      modelTypeId: 'general',
      downloadUrl:
          'https://huggingface.co/litert-community/SmolLM-135M-Instruct/resolve/main/SmolLM-135M-Instruct_seq128_q8_ekv1280.task',
      maxTokens: 1280,
    ),
    GemmaModelSpec(
      id: 'functiongemma_270m',
      displayName: 'FunctionGemma 270M',
      sizeBytes: 284 * _mb,
      badge: ModelBadge.fast,
      modelTypeId: 'functionGemma',
      downloadUrl:
          'https://huggingface.co/litert-community/functiongemma-270m/resolve/main/functiongemma-270m-it-q8.litertlm',
      maxTokens: 2048,
    ),
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
          'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
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
      id: 'qwen3_06b',
      displayName: 'Qwen3 · 0.6B',
      sizeBytes: 586 * _mb,
      badge: ModelBadge.balanced,
      modelTypeId: 'qwen3',
      downloadUrl:
          'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B_multi-prefill-seq_q8_ekv4096.litertlm',
      maxTokens: 4096,
    ),
    GemmaModelSpec(
      id: 'qwen25_15b',
      displayName: 'Qwen 2.5 · 1.5B',
      sizeBytes: 1600 * _mb,
      badge: ModelBadge.detailed,
      modelTypeId: 'qwen',
      downloadUrl:
          'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
      maxTokens: 4096,
    ),
    GemmaModelSpec(
      id: 'deepseek_r1',
      displayName: 'DeepSeek R1',
      sizeBytes: 1700 * _mb,
      badge: ModelBadge.reasoning,
      modelTypeId: 'deepSeek',
      downloadUrl:
          'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv1280.task',
      maxTokens: 4096,
    ),
    GemmaModelSpec(
      id: 'gemma4_e2b',
      displayName: 'Gemma 4 · E2B',
      sizeBytes: 2400 * _mb,
      badge: ModelBadge.multimodal,
      modelTypeId: 'gemma4',
      downloadUrl:
          'https://huggingface.co/google/gemma-4-e2b-it-litert/resolve/main/gemma-4-e2b-it-int4.litertlm',
      maxTokens: 4096,
      supportsAudio: true,
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
      id: 'phi4_mini',
      displayName: 'Phi-4 Mini',
      sizeBytes: 3900 * _mb,
      badge: ModelBadge.reasoning,
      modelTypeId: 'phi',
      downloadUrl:
          'https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/Phi-4-mini-instruct_multi-prefill-seq_q8_ekv1280.task',
      maxTokens: 4096,
    ),
    GemmaModelSpec(
      id: 'gemma4_e4b',
      displayName: 'Gemma 4 · E4B',
      sizeBytes: 4300 * _mb,
      badge: ModelBadge.multimodal,
      modelTypeId: 'gemma4',
      downloadUrl:
          'https://huggingface.co/google/gemma-4-e4b-it-litert/resolve/main/gemma-4-e4b-it-int4.litertlm',
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
      models.firstWhere((m) => m.id == id, orElse: () => models.firstWhere((m) => m.id == defaultId));

  /// Models that can also transcribe audio on-device (multimodal).
  static List<GemmaModelSpec> get audioCapable =>
      models.where((m) => m.supportsAudio).toList();
}
