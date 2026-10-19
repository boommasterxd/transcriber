import 'app_accent.dart';
import 'app_language.dart';

/// Persisted appearance choice; Flutter mapping belongs to the UI boundary.
enum AppThemeMode { system, light, dark }

class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = AppThemeMode.system,
    this.accent = AppAccent.blue,
    this.language = AppLanguage.de,
  });

  final AppThemeMode themeMode;
  final AppAccent accent;
  final AppLanguage language;

  AppearanceSettings copyWith({
    AppThemeMode? themeMode,
    AppAccent? accent,
    AppLanguage? language,
  }) => AppearanceSettings(
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
    language: language ?? this.language,
  );
}
