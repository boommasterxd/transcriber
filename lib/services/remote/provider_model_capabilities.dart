/// Provider-specific model capability rules for the model metadata exposed by
/// the OpenAI and Gemini catalog endpoints.
abstract final class ProviderModelCapabilities {
  static bool isOpenAiTranscriptionModel(String modelId) {
    return usesOpenAiTranscriptionEndpoint(modelId) ||
        usesOpenAiAudioChat(modelId);
  }

  static bool usesOpenAiTranscriptionEndpoint(String modelId) {
    final id = modelId.toLowerCase();
    return id == 'whisper-1' || id.contains('transcribe');
  }

  static bool usesOpenAiAudioChat(String modelId) {
    final id = modelId.toLowerCase();
    if (!id.contains('audio')) return false;
    const incompatibleFamilies = [
      'moderation',
      'realtime',
      'speech',
      'transcribe',
      'tts',
    ];
    return !incompatibleFamilies.any(id.contains);
  }

  static bool isGeminiTranscriptionModel(
    String modelId,
    Set<String> supportedMethods,
  ) {
    if (usesGeminiNativeTranscription(modelId)) return true;
    if (!supportedMethods.contains('generateContent')) return false;

    final id = modelId.toLowerCase();
    if (!id.startsWith('gemini-')) return false;
    const incompatibleFamilies = [
      'computer-use',
      'deep-research',
      'embedding',
      'image',
      'live',
      'native-audio',
      'robotics',
      'tts',
    ];
    return !incompatibleFamilies.any(id.contains);
  }

  static bool usesGeminiNativeTranscription(String modelId) {
    final id = modelId.toLowerCase();
    return id.contains('transcribe') && !id.contains('live');
  }
}
