/// Builds the provider-neutral instruction used with general multimodal
/// models that do not expose a dedicated transcription operation.
String buildTranscriptionPrompt(String? languageCode) {
  const instruction =
      'Transcribe the attached audio verbatim. Return only the transcript '
      'as plain text.';
  if (languageCode == null || languageCode.isEmpty || languageCode == 'auto') {
    return instruction;
  }
  return '$instruction The spoken language is $languageCode.';
}
