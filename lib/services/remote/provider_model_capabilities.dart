/// Purpose heuristics for live provider catalogs with incomplete capabilities.
/// Names and descriptions are hints, not authoritative modality metadata.
abstract final class ProviderModelCapabilities {
  static final _safeId = RegExp(r'^[a-z0-9]+(?:[._-][a-z0-9]+)*$');
  static final _fineTunedId = RegExp(
    r'^ft:([^:]+):[a-zA-Z0-9._-]+:[a-zA-Z0-9._-]*:[a-zA-Z0-9_-]+$',
  );
  static final _openAiText = RegExp(r'^(?:gpt-|chatgpt-|o\d+(?:[-.]|$))');
  static final _openAiAudio = RegExp(r'^(?:gpt-|whisper-)');
  static final _specialistId = _tokens(
    'tts|image|imagen|video|sora|embedding|embeddings|moderation|robotics|'
    'robotic|omni|banana|veo|lyria|live|realtime|translate|translation|'
    'text[._-]+to[._-]+speech|speech[._-]+(?:generation|synthesis)',
  );
  static final _specialistDescription = _tokens(
    'tts|robotics|robotic|omni|banana|imagen|veo|lyria|embeddings?|moderation|'
    '(?:image|video|music)[\\s_-]+model|'
    '(?:image|video|music|audio|speech)[\\s_-]+(?:generation|editing|synthesis)|'
    'text[\\s_-]+to[\\s_-]+(?:speech|audio|image|video)|'
    '(?:live|real[\\s_-]*time)[\\s_-]+(?:audio|voice|conversation)',
  );
  static final _audioRole = _tokens('audio');
  static final _transcriptionRole = _tokens(
    'transcribe|transcription|asr|whisper',
  );
  static final _asrDescription = _tokens(
    '(?:dedicated|specialized)[\\s_-]+(?:transcribe|transcription|asr)|'
    '(?:transcription|asr|speech[\\s_-]+(?:recognition|to[\\s_-]+text))'
    '[\\s_-]+model|model[\\s_-]+for[\\s_-]+'
    '(?:transcription|asr|speech[\\s_-]+recognition)',
  );
  static final _openAiNonChat = _tokens(
    'codex|pro|search|research|agent|agents|computer|oss',
  );
  static final _textOnly = _tokens('gemma|(?:text|code)[\\s_-]+only');
  static final _geminiSpecialistRole = _tokens(
    'antigravity|agents?|harness|deep[\\s._-]+research|'
    '(?:computer|browser)[\\s._-]+use',
  );
  static final _geminiSpecialistPurpose = _tokens(
    '(?:managed|autonomous|research|dedicated|specialized)[\\s._-]+agent|'
    '(?:agentic[\\s._-]+)?harness|'
    '(?:agent|deep[\\s._-]+research|computer[\\s._-]+use|'
    'browser[\\s._-]+use)[\\s._-]+model|'
    '(?:model|designed|specialized)[\\s._-]+for[\\s._-]+'
    '(?:agents?|deep[\\s._-]+research|computer[\\s._-]+use|'
    'browser[\\s._-]+use)',
  );

  static bool isOpenAiSummaryModel(String modelId) {
    final base = _openAiSummaryBase(modelId);
    return base != null &&
        _openAiText.hasMatch(base) &&
        !_specialistId.hasMatch(base) &&
        !_openAiNonChat.hasMatch(base) &&
        !_audioRole.hasMatch(base) &&
        !_transcriptionRole.hasMatch(base);
  }

  static String? _openAiSummaryBase(String id) {
    if (_isSafe(id)) return id;
    if (id.length > 200) return null;
    final match = _fineTunedId.firstMatch(id);
    if (match == null || match.end != id.length) return null;
    final base = match.group(1)!;
    return _isSafe(base) ? base : null;
  }

  static bool isOpenAiTranscriptionModel(String modelId) =>
      usesOpenAiTranscriptionEndpoint(modelId) || usesOpenAiAudioChat(modelId);

  static bool usesOpenAiTranscriptionEndpoint(String modelId) =>
      _isOpenAiAudioCandidate(modelId) &&
      (_transcriptionRole.hasMatch(modelId) || modelId.startsWith('whisper-'));

  static bool usesOpenAiAudioChat(String modelId) =>
      _isOpenAiAudioCandidate(modelId) &&
      _audioRole.hasMatch(modelId) &&
      !_transcriptionRole.hasMatch(modelId);

  static bool isGeminiSummaryModel(
    String modelId,
    Set<String> supportedMethods, {
    String? displayName,
    String? description,
  }) =>
      _isGeminiGenerationModel(modelId, supportedMethods) &&
      !_transcriptionRole.hasMatch(modelId) &&
      !_hasSpecialistMetadata(displayName, description) &&
      !_transcriptionRole.hasMatch(displayName?.toLowerCase() ?? '') &&
      !_asrDescription.hasMatch(description?.toLowerCase() ?? '');

  static bool isGeminiTranscriptionModel(
    String modelId,
    Set<String> supportedMethods, {
    String? displayName,
    String? description,
  }) {
    if (!_isGeminiCandidate(modelId) ||
        _hasSpecialistMetadata(displayName, description)) {
      return false;
    }
    if (usesGeminiNativeTranscription(modelId)) return true;
    return supportedMethods.contains('generateContent') &&
        !_textOnly.hasMatch(
          '$modelId ${displayName ?? ''} ${description ?? ''}'.toLowerCase(),
        );
  }

  static bool usesGeminiNativeTranscription(String modelId) =>
      _isGeminiCandidate(modelId) && _transcriptionRole.hasMatch(modelId);

  static bool _isGeminiGenerationModel(String id, Set<String> methods) =>
      _isGeminiCandidate(id) && methods.contains('generateContent');

  static bool _isGeminiCandidate(String id) =>
      _isSafe(id) &&
      !_specialistId.hasMatch(id) &&
      !_geminiSpecialistRole.hasMatch(id);

  static bool _isOpenAiAudioCandidate(String id) =>
      _isSafe(id) &&
      _openAiAudio.hasMatch(id) &&
      !_specialistId.hasMatch(id) &&
      !_openAiNonChat.hasMatch(id);

  static bool _hasSpecialistMetadata(String? label, String? description) =>
      _specialistId.hasMatch(label?.toLowerCase() ?? '') ||
      _geminiSpecialistRole.hasMatch(label?.toLowerCase() ?? '') ||
      _geminiSpecialistPurpose.hasMatch(description?.toLowerCase() ?? '') ||
      _specialistDescription.hasMatch(
        '${label ?? ''} ${description ?? ''}'.toLowerCase(),
      );

  static bool _isSafe(String id) =>
      id.length <= 200 && _safeId.firstMatch(id)?.end == id.length;

  static RegExp _tokens(String alternatives) =>
      RegExp('(?:^|[^a-z0-9])(?:$alternatives)(?:\$|[^a-z0-9])');
}
