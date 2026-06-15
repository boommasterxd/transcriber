import 'package:flutter/material.dart' show Brightness;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_accent.dart';
import '../catalog/remote_catalog.dart';
import '../catalog/gemma_catalog.dart';
import '../catalog/whisper_catalog.dart';
import 'processing_mode.dart';
import 'remote_provider.dart';

/// Immutable snapshot of all user preferences.
///
/// Transcription and summarization are configured **independently** — each can
/// run on-device or via a cloud provider, in any combination. Cloud model ids
/// are the raw identifiers chosen from each provider's live model list. API keys
/// are stored separately in secure storage.
class AppSettings {
  const AppSettings({
    required this.brightness,
    required this.accent,
    required this.language,
    required this.asrMode,
    required this.summaryMode,
    required this.whisperModelId,
    required this.gemmaModelId,
    required this.asrProvider,
    required this.summaryProvider,
    required this.chatModelByProvider,
    required this.asrModelByProvider,
    required this.autoDeleteAudio,
    required this.onboarded,
    required this.hfToken,
  });

  final Brightness brightness;
  final AppAccent accent;
  final AppLanguage language;

  final ProcessingMode asrMode;
  final ProcessingMode summaryMode;

  final String whisperModelId;
  final String gemmaModelId;

  final RemoteProviderId asrProvider;
  final RemoteProviderId summaryProvider;

  /// Selected cloud model id per provider (chat/summary and ASR respectively).
  final Map<RemoteProviderId, String> chatModelByProvider;
  final Map<RemoteProviderId, String> asrModelByProvider;

  final bool autoDeleteAudio;
  final bool onboarded;
  final String hfToken;

  bool get isDark => brightness == Brightness.dark;
  bool get isFullyLocal => asrMode.isLocal && summaryMode.isLocal;

  String summaryModelId(RemoteProviderId p) =>
      chatModelByProvider[p] ?? RemoteCatalog.chatDefault(p);

  String asrModelId(RemoteProviderId p) =>
      asrModelByProvider[p] ?? RemoteCatalog.asrDefault(p);

  factory AppSettings.initial() => AppSettings(
        brightness: Brightness.light,
        accent: AppAccent.violet,
        language: AppLanguage.de,
        asrMode: ProcessingMode.onDevice,
        summaryMode: ProcessingMode.onDevice,
        whisperModelId: WhisperCatalog.defaultId,
        gemmaModelId: GemmaCatalog.defaultId,
        asrProvider: RemoteProviderId.openai,
        summaryProvider: RemoteProviderId.anthropic,
        chatModelByProvider: const {},
        asrModelByProvider: const {},
        autoDeleteAudio: true,
        onboarded: false,
        hfToken: '',
      );

  AppSettings copyWith({
    Brightness? brightness,
    AppAccent? accent,
    AppLanguage? language,
    ProcessingMode? asrMode,
    ProcessingMode? summaryMode,
    String? whisperModelId,
    String? gemmaModelId,
    RemoteProviderId? asrProvider,
    RemoteProviderId? summaryProvider,
    Map<RemoteProviderId, String>? chatModelByProvider,
    Map<RemoteProviderId, String>? asrModelByProvider,
    bool? autoDeleteAudio,
    bool? onboarded,
    String? hfToken,
  }) =>
      AppSettings(
        brightness: brightness ?? this.brightness,
        accent: accent ?? this.accent,
        language: language ?? this.language,
        asrMode: asrMode ?? this.asrMode,
        summaryMode: summaryMode ?? this.summaryMode,
        whisperModelId: whisperModelId ?? this.whisperModelId,
        gemmaModelId: gemmaModelId ?? this.gemmaModelId,
        asrProvider: asrProvider ?? this.asrProvider,
        summaryProvider: summaryProvider ?? this.summaryProvider,
        chatModelByProvider: chatModelByProvider ?? this.chatModelByProvider,
        asrModelByProvider: asrModelByProvider ?? this.asrModelByProvider,
        autoDeleteAudio: autoDeleteAudio ?? this.autoDeleteAudio,
        onboarded: onboarded ?? this.onboarded,
        hfToken: hfToken ?? this.hfToken,
      );

  Map<String, dynamic> toJson() => {
        'brightness': brightness == Brightness.dark ? 'dark' : 'light',
        'accent': accent.id,
        'language': language.code,
        'asrMode': asrMode.id,
        'summaryMode': summaryMode.id,
        'whisperModelId': whisperModelId,
        'gemmaModelId': gemmaModelId,
        'asrProvider': asrProvider.id,
        'summaryProvider': summaryProvider.id,
        'chatModelByProvider': chatModelByProvider.map((k, v) => MapEntry(k.id, v)),
        'asrModelByProvider': asrModelByProvider.map((k, v) => MapEntry(k.id, v)),
        'autoDeleteAudio': autoDeleteAudio,
        'onboarded': onboarded,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j, {required String hfToken}) {
    Map<RemoteProviderId, String> parseMap(String key) {
      final raw = (j[key] as Map?)?.cast<String, dynamic>() ?? const {};
      return {
        for (final e in raw.entries) RemoteProviderId.fromId(e.key): e.value.toString(),
      };
    }

    final legacyMode = j['mode'] as String?;
    ProcessingMode mode(String key) => ProcessingMode.fromId((j[key] as String?) ?? legacyMode);

    return AppSettings(
      brightness: j['brightness'] == 'dark' ? Brightness.dark : Brightness.light,
      accent: AppAccent.fromId(j['accent'] as String?),
      language: AppLanguage.fromCode(j['language'] as String?),
      asrMode: mode('asrMode'),
      summaryMode: mode('summaryMode'),
      whisperModelId: j['whisperModelId'] as String? ?? WhisperCatalog.defaultId,
      gemmaModelId: j['gemmaModelId'] as String? ?? GemmaCatalog.defaultId,
      asrProvider: _asrProviderFromId(j['asrProvider'] as String?),
      summaryProvider: RemoteProviderId.fromId(j['summaryProvider'] as String?),
      chatModelByProvider: parseMap('chatModelByProvider'),
      asrModelByProvider: parseMap('asrModelByProvider'),
      autoDeleteAudio: j['autoDeleteAudio'] as bool? ?? true,
      onboarded: j['onboarded'] as bool? ?? false,
      hfToken: hfToken,
    );
  }

  static RemoteProviderId _asrProviderFromId(String? id) {
    final p = RemoteProviderId.fromId(id);
    return RemoteCatalog.asrProviders.contains(p) ? p : RemoteProviderId.openai;
  }
}
