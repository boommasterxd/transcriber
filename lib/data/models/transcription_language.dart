/// Language used for transcription. `auto` lets the ASR model detect it.
enum TranscriptionLanguage {
  auto('auto'),
  de('de'),
  en('en');

  const TranscriptionLanguage(this.code);
  final String code;

  static TranscriptionLanguage fromCode(String? code) =>
      TranscriptionLanguage.values.firstWhere((l) => l.code == code, orElse: () => TranscriptionLanguage.auto);
}
