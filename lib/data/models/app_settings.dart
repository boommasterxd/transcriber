import 'package:flutter/material.dart' show Brightness;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_accent.dart';
import '../catalog/gemma_catalog.dart';
import '../catalog/remote_catalog.dart';
import '../catalog/whisper_catalog.dart';
import 'processing_mode.dart';
import 'remote_provider.dart';

/// Immutable snapshot of all user preferences.
///
/// Transcription and summarization are configured **independently** — each can
/// run on-device or via a cloud provider, in any combination. API keys are
/// stored separately in secure storage.
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
    required this.remoteModelByProvider,
    required this.autoDeleteAudio,
    required this.onboarded,
    required this.hfToken,
  });

  final Brightness brightness;
  final AppAccent accent;
  final AppLanguage language;

  /// Per-stage processing backends.
  final ProcessingMode asrMode;
  final ProcessingMode summaryMode;

  /// Selected on-device model ids.
  final String whisperModelId;
  final String gemmaModelId;

  /// Cloud provider for each stage. ASR is limited to providers with native ASR
  /// (OpenAI, Google); summary can use any provider.
  final RemoteProviderId asrProvider;
  final RemoteProviderId summaryProvider;

  /// Per-provider chosen summary model id.
  final Map<RemoteProviderId, String> remoteModelByProvider;

  final bool autoDeleteAudio;
  final bool onboarded;

  /// Optional Hugging Face token for gated model downloads.
  final String hfToken;

  bool get isDark => brightness == Brightness.dark;

  bool get isFullyLocal => asrMode.isLocal && summaryMode.isLocal;

  String remoteModelId(RemoteProviderId p) =>
      remoteModelByProvider[p] ?? RemoteCatalog.defaultModelId[p]!;

  RemoteModelSpec get summaryRemoteModel =>
      RemoteCatalog.model(summaryProvider, remoteModelId(summaryProvider));

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
        remoteModelByProvider: Map.of(RemoteCatalog.defaultModelId),
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
    Map<RemoteProviderId, String>? remoteModelByProvider,
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
        remoteModelByProvider: remoteModelByProvider ?? this.remoteModelByProvider,
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
        'remoteModelByProvider': remoteModelByProvider.map((k, v) => MapEntry(k.id, v)),
        'autoDeleteAudio': autoDeleteAudio,
        'onboarded': onboarded,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j, {required String hfToken}) {
    final raw = (j['remoteModelByProvider'] as Map?)?.cast<String, dynamic>() ?? {};
    final remoteMap = Map<RemoteProviderId, String>.of(RemoteCatalog.defaultModelId);
    for (final entry in raw.entries) {
      remoteMap[RemoteProviderId.fromId(entry.key)] = entry.value.toString();
    }

    // Back-compat: an older single `mode`/`provider` maps onto both stages.
    final legacyMode = j['mode'] as String?;
    final legacyProvider = j['provider'] as String?;

    ProcessingMode mode(String key) =>
        ProcessingMode.fromId((j[key] as String?) ?? legacyMode);

    return AppSettings(
      brightness: j['brightness'] == 'dark' ? Brightness.dark : Brightness.light,
      accent: AppAccent.fromId(j['accent'] as String?),
      language: AppLanguage.fromCode(j['language'] as String?),
      asrMode: mode('asrMode'),
      summaryMode: mode('summaryMode'),
      whisperModelId: j['whisperModelId'] as String? ?? WhisperCatalog.defaultId,
      gemmaModelId: j['gemmaModelId'] as String? ?? GemmaCatalog.defaultId,
      asrProvider: _asrProviderFromId((j['asrProvider'] as String?) ?? legacyProvider),
      summaryProvider: RemoteProviderId.fromId((j['summaryProvider'] as String?) ?? legacyProvider),
      remoteModelByProvider: remoteMap,
      autoDeleteAudio: j['autoDeleteAudio'] as bool? ?? true,
      onboarded: j['onboarded'] as bool? ?? false,
      hfToken: hfToken,
    );
  }

  /// ASR only supports providers with native transcription.
  static RemoteProviderId _asrProviderFromId(String? id) {
    final p = RemoteProviderId.fromId(id);
    return RemoteCatalog.asrProviders.contains(p) ? p : RemoteProviderId.openai;
  }
}
