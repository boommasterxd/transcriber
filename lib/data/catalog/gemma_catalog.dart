import '../models/gemma_model_spec.dart';
import '../models/model_badge.dart';

/// On-device summary models from the `flutter_gemma` package.
///
/// All entries are public LiteRT/MediaPipe artifacts on Hugging Face that
/// download **without an access token**. (Google's gated `Gemma 3` repos return
/// 401, so they're intentionally excluded; Gemma 4 on `litert-community` is
/// open.) Audio-capable Gemma 4 models can also transcribe.
const int _mb = 1024 * 1024;

class GemmaCatalog {
  const GemmaCatalog._();

  /// Sorted alphabetically by display name for the settings list.
  static final List<GemmaModelSpec> models = List.of(_models)
    ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

  static const List<GemmaModelSpec> _models = [
    GemmaModelSpec(
      id: 'smollm_135m',
      displayName: 'SmolLM 135M',
      sizeBytes: 135 * _mb,
      badge: ModelBadge.veryFast,
      modelTypeId: 'general',
      downloadUrl:
          'https://huggingface.co/litert-community/SmolLM-135M-Instruct/resolve/main/SmolLM-135M-Instruct_multi-prefill-seq_q8_ekv1280.task',
      maxTokens: 1280,
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
      id: 'qwen3_06b',
      displayName: 'Qwen3 · 0.6B',
      sizeBytes: 586 * _mb,
      badge: ModelBadge.balanced,
      modelTypeId: 'qwen3',
      downloadUrl:
          'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm',
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
          'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/deepseek_q8_ekv1280.task',
      maxTokens: 4096,
    ),
    GemmaModelSpec(
      id: 'gemma4_e2b',
      displayName: 'Gemma 4 · E2B',
      sizeBytes: 2400 * _mb,
      badge: ModelBadge.recommended,
      modelTypeId: 'gemma4',
      downloadUrl:
          'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
      maxTokens: 4096,
      supportsAudio: true,
      recommended: true,
    ),
    GemmaModelSpec(
      id: 'phi4_mini',
      displayName: 'Phi-4 Mini',
      sizeBytes: 3900 * _mb,
      badge: ModelBadge.reasoning,
      modelTypeId: 'general',
      downloadUrl:
          'https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/Phi-4-mini-instruct_multi-prefill-seq_q8_ekv4096.task',
      maxTokens: 4096,
    ),
    GemmaModelSpec(
      id: 'gemma4_e4b',
      displayName: 'Gemma 4 · E4B',
      sizeBytes: 4300 * _mb,
      badge: ModelBadge.multimodal,
      modelTypeId: 'gemma4',
      downloadUrl:
          'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
      maxTokens: 4096,
      supportsAudio: true,
    ),
  ];

  static const String defaultId = 'gemma4_e2b';

  static GemmaModelSpec byId(String id) =>
      models.firstWhere((m) => m.id == id, orElse: () => models.firstWhere((m) => m.id == defaultId));

  static List<GemmaModelSpec> get audioCapable => models.where((m) => m.supportsAudio).toList();
}
