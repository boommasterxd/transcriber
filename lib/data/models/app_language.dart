/// Supported interface languages, independent of localized presentation copy.
enum AppLanguage {
  de('de'),
  en('en');

  const AppLanguage(this.code);

  final String code;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
    (language) => language.code == code,
    orElse: () => AppLanguage.de,
  );
}
