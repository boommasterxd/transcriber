import '../catalog/remote_catalog.dart';
import 'app_accent.dart';
import 'app_language.dart';
import 'appearance_settings.dart';
import 'processing_settings.dart';
import 'remote_provider.dart';
import 'transcription_language.dart';

export 'appearance_settings.dart';
export 'processing_settings.dart';

/// Immutable snapshot of all user preferences.
///
/// Transcription and summarization are configured independently. API keys are
/// stored separately in secure storage and never serialized with settings.
class AppSettings {
  const AppSettings({
    this.appearance = const AppearanceSettings(),
    this.transcription = const TranscriptionSettings(),
    this.summary = const SummarySettings(),
    this.autoDeleteAudio = false,
    this.onboarded = false,
  });

  final AppearanceSettings appearance;
  final TranscriptionSettings transcription;
  final SummarySettings summary;

  /// System / Light / Dark. `system` follows the OS setting.
  AppThemeMode get themeMode => appearance.themeMode;
  AppAccent get accent => appearance.accent;
  AppLanguage get language => appearance.language;
  TranscriptionLanguage get transcriptionLanguage => transcription.language;
  RemoteProviderId get asrProvider => transcription.provider;
  RemoteProviderId get summaryProvider => summary.provider;

  /// Selected cloud model id per provider (chat/summary and ASR respectively).
  Map<RemoteProviderId, String> get chatModelByProvider => summary.models;
  Map<RemoteProviderId, String> get asrModelByProvider => transcription.models;

  final bool autoDeleteAudio;

  /// When false, processing stops after transcription, without an AI summary.
  bool get summarizeEnabled => summary.enabled;
  final bool onboarded;

  String summaryModelId(RemoteProviderId p) =>
      chatModelByProvider[p] ?? RemoteCatalog.chatDefault(p);

  String asrModelId(RemoteProviderId p) =>
      asrModelByProvider[p] ?? RemoteCatalog.asrDefault(p);

  factory AppSettings.initial() => const AppSettings();

  AppSettings copyWith({
    AppearanceSettings? appearance,
    TranscriptionSettings? transcription,
    SummarySettings? summary,
    bool? autoDeleteAudio,
    bool? onboarded,
  }) => AppSettings(
    appearance: appearance ?? this.appearance,
    transcription: transcription ?? this.transcription,
    summary: summary ?? this.summary,
    autoDeleteAudio: autoDeleteAudio ?? this.autoDeleteAudio,
    onboarded: onboarded ?? this.onboarded,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'accent': accent.id,
    'language': language.code,
    'transcriptionLanguage': transcriptionLanguage.code,
    'asrProvider': asrProvider.id,
    'summaryProvider': summaryProvider.id,
    'chatModelByProvider': chatModelByProvider.map((k, v) => MapEntry(k.id, v)),
    'asrModelByProvider': asrModelByProvider.map((k, v) => MapEntry(k.id, v)),
    'autoDeleteAudio': autoDeleteAudio,
    'summarizeEnabled': summarizeEnabled,
    'onboarded': onboarded,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    Map<RemoteProviderId, String> parseMap(String key) {
      final raw = (j[key] as Map?)?.cast<String, dynamic>() ?? const {};
      return {
        for (final e in raw.entries)
          RemoteProviderId.fromId(e.key): e.value.toString(),
      };
    }

    return AppSettings(
      appearance: AppearanceSettings(
        themeMode: _themeModeFrom(j),
        accent: AppAccent.fromId(j['accent'] as String?),
        language: AppLanguage.fromCode(j['language'] as String?),
      ),
      transcription: TranscriptionSettings(
        language: TranscriptionLanguage.fromCode(
          j['transcriptionLanguage'] as String?,
        ),
        provider: _asrProviderFromId(j['asrProvider'] as String?),
        models: parseMap('asrModelByProvider'),
      ),
      summary: SummarySettings(
        provider: RemoteProviderId.fromId(j['summaryProvider'] as String?),
        models: parseMap('chatModelByProvider'),
        enabled: j['summarizeEnabled'] as bool? ?? true,
      ),
      autoDeleteAudio: j['autoDeleteAudio'] as bool? ?? false,
      onboarded: j['onboarded'] as bool? ?? false,
    );
  }

  static AppThemeMode _themeModeFrom(Map<String, dynamic> j) {
    final raw = j['themeMode'] as String?;
    if (raw != null) {
      return AppThemeMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => AppThemeMode.system,
      );
    }
    // Back-compat: older builds stored a light/dark brightness.
    return switch (j['brightness']) {
      'dark' => AppThemeMode.dark,
      'light' => AppThemeMode.light,
      _ => AppThemeMode.system,
    };
  }

  static RemoteProviderId _asrProviderFromId(String? id) {
    final p = RemoteProviderId.fromId(id);
    return RemoteCatalog.asrProviders.contains(p) ? p : RemoteProviderId.google;
  }
}
