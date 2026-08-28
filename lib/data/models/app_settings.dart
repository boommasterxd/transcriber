import 'package:flutter/material.dart' show ThemeMode;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_accent.dart';
import '../catalog/remote_catalog.dart';
import 'remote_provider.dart';
import 'transcription_language.dart';

/// Immutable snapshot of all user preferences.
///
/// Transcription and summarization are configured independently. API keys are
/// stored separately in secure storage and never serialized with settings.
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.accent,
    required this.language,
    required this.transcriptionLanguage,
    required this.asrProvider,
    required this.summaryProvider,
    required this.chatModelByProvider,
    required this.asrModelByProvider,
    required this.autoDeleteAudio,
    required this.summarizeEnabled,
    required this.onboarded,
  });

  /// System / Light / Dark. `system` follows the OS setting.
  final ThemeMode themeMode;
  final AppAccent accent;
  final AppLanguage language;
  final TranscriptionLanguage transcriptionLanguage;

  final RemoteProviderId asrProvider;
  final RemoteProviderId summaryProvider;

  /// Selected cloud model id per provider (chat/summary and ASR respectively).
  final Map<RemoteProviderId, String> chatModelByProvider;
  final Map<RemoteProviderId, String> asrModelByProvider;

  final bool autoDeleteAudio;

  /// When false, processing stops after transcription, without an AI summary.
  final bool summarizeEnabled;
  final bool onboarded;

  String summaryModelId(RemoteProviderId p) =>
      chatModelByProvider[p] ?? RemoteCatalog.chatDefault(p);

  String asrModelId(RemoteProviderId p) =>
      asrModelByProvider[p] ?? RemoteCatalog.asrDefault(p);

  factory AppSettings.initial() => const AppSettings(
    themeMode: ThemeMode.system,
    accent: AppAccent.blue,
    language: AppLanguage.de,
    transcriptionLanguage: TranscriptionLanguage.auto,
    asrProvider: RemoteProviderId.google,
    summaryProvider: RemoteProviderId.google,
    chatModelByProvider: {},
    asrModelByProvider: {},
    autoDeleteAudio: false,
    summarizeEnabled: true,
    onboarded: false,
  );

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppAccent? accent,
    AppLanguage? language,
    TranscriptionLanguage? transcriptionLanguage,
    RemoteProviderId? asrProvider,
    RemoteProviderId? summaryProvider,
    Map<RemoteProviderId, String>? chatModelByProvider,
    Map<RemoteProviderId, String>? asrModelByProvider,
    bool? autoDeleteAudio,
    bool? summarizeEnabled,
    bool? onboarded,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
    language: language ?? this.language,
    transcriptionLanguage: transcriptionLanguage ?? this.transcriptionLanguage,
    asrProvider: asrProvider ?? this.asrProvider,
    summaryProvider: summaryProvider ?? this.summaryProvider,
    chatModelByProvider: chatModelByProvider ?? this.chatModelByProvider,
    asrModelByProvider: asrModelByProvider ?? this.asrModelByProvider,
    autoDeleteAudio: autoDeleteAudio ?? this.autoDeleteAudio,
    summarizeEnabled: summarizeEnabled ?? this.summarizeEnabled,
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
      themeMode: _themeModeFrom(j),
      accent: AppAccent.fromId(j['accent'] as String?),
      language: AppLanguage.fromCode(j['language'] as String?),
      transcriptionLanguage: TranscriptionLanguage.fromCode(
        j['transcriptionLanguage'] as String?,
      ),
      asrProvider: _asrProviderFromId(j['asrProvider'] as String?),
      summaryProvider: _summaryProviderFromId(j['summaryProvider'] as String?),
      chatModelByProvider: parseMap('chatModelByProvider'),
      asrModelByProvider: parseMap('asrModelByProvider'),
      autoDeleteAudio: j['autoDeleteAudio'] as bool? ?? false,
      summarizeEnabled: j['summarizeEnabled'] as bool? ?? true,
      onboarded: j['onboarded'] as bool? ?? false,
    );
  }

  static ThemeMode _themeModeFrom(Map<String, dynamic> j) {
    final raw = j['themeMode'] as String?;
    if (raw != null) {
      return ThemeMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => ThemeMode.system,
      );
    }
    // Back-compat: older builds stored a light/dark brightness.
    return switch (j['brightness']) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  static RemoteProviderId _asrProviderFromId(String? id) {
    final p = RemoteProviderId.fromId(id);
    return RemoteCatalog.asrProviders.contains(p) ? p : RemoteProviderId.google;
  }

  static RemoteProviderId _summaryProviderFromId(String? id) =>
      RemoteProviderId.fromId(id);
}
