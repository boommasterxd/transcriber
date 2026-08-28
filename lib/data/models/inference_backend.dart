/// Preferred compute backend for on-device inference (Gemma summaries).
/// `auto` lets flutter_gemma choose (GPU with CPU fallback). NPU is Android-only
/// and device-dependent.
enum InferenceBackend {
  auto('auto', 'Auto'),
  gpu('gpu', 'GPU'),
  cpu('cpu', 'CPU'),
  npu('npu', 'NPU');

  const InferenceBackend(this.id, this.label);
  final String id;
  final String label;

  static InferenceBackend fromId(String? id) => InferenceBackend.values
      .firstWhere((b) => b.id == id, orElse: () => InferenceBackend.auto);
}
