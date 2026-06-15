import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_accent.dart';
import 'package:flutter/material.dart' show Brightness;

import '../catalog/remote_catalog.dart';
import '../catalog/gemma_catalog.dart';
import '../catalog/whisper_catalog.dart';
import 'processing_mode.dart';
import 'remote_provider.dart';

/// Immutable snapshot of all user preferences. Persisted by [SettingsRepository]
/// (API keys are stored separately in secure storage).
class AppSettings {
  const AppSettings({
    required this.brightness,
    required this.accent,
    required this.language,
    required this.mode,
    required this.whisperModelId,
    required this.gemmaModelId,
    required this.provider,
    required this.remoteModelByProvider,
    required this.autoDeleteAudio,
    required this.onboarded,
    required this.hfToken,
  });

  final Brightness brightness;
  final AppAccent accent;
  final AppLanguage language;
  final ProcessingMode mode;

  /// Selected on-device model ids.
  final String whisperModelId;
  final String gemmaModelId;

  /// Active cloud provider + per-provider chosen model id.
  final RemoteProviderId provider;
  final Map<RemoteProviderId, String> remoteModelByProvider;

  final bool autoDeleteAudio;
  final bool onboarded;

  /// Optional Hugging Face token for gated model downloads.
  final String hfToken;

  bool get isDark => brightness == Brightness.dark;

  String remoteModelId(RemoteProviderId p) =>
      remoteModelByProvider[p] ?? RemoteCatalog.defaultModelId[p]!;

  RemoteModelSpec get currentRemoteModel =>
      RemoteCatalog.model(provider, remoteModelId(provider));

  factory AppSettings.initial() => AppSettings(
        brightness: Brightness.light,
        accent: AppAccent.violet,
        language: AppLanguage.de,
        mode: ProcessingMode.onDevice,
        whisperModelId: WhisperCatalog.defaultId,
        gemmaModelId: GemmaCatalog.defaultId,
        provider: RemoteProviderId.anthropic,
        remoteModelByProvider: Map.of(RemoteCatalog.defaultModelId),
        autoDeleteAudio: true,
        onboarded: false,
        hfToken: '',
      );

  AppSettings copyWith({
    Brightness? brightness,
    AppAccent? accent,
    AppLanguage? language,
    ProcessingMode? mode,
    String? whisperModelId,
    String? gemmaModelId,
    RemoteProviderId? provider,
    Map<RemoteProviderId, String>? remoteModelByProvider,
    bool? autoDeleteAudio,
    bool? onboarded,
    String? hfToken,
  }) =>
      AppSettings(
        brightness: brightness ?? this.brightness,
        accent: accent ?? this.accent,
        language: language ?? this.language,
        mode: mode ?? this.mode,
        whisperModelId: whisperModelId ?? this.whisperModelId,
        gemmaModelId: gemmaModelId ?? this.gemmaModelId,
        provider: provider ?? this.provider,
        remoteModelByProvider: remoteModelByProvider ?? this.remoteModelByProvider,
        autoDeleteAudio: autoDeleteAudio ?? this.autoDeleteAudio,
        onboarded: onboarded ?? this.onboarded,
        hfToken: hfToken ?? this.hfToken,
      );

  Map<String, dynamic> toJson() => {
        'brightness': brightness == Brightness.dark ? 'dark' : 'light',
        'accent': accent.id,
        'language': language.code,
        'mode': mode.id,
        'whisperModelId': whisperModelId,
        'gemmaModelId': gemmaModelId,
        'provider': provider.id,
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
    return AppSettings(
      brightness: j['brightness'] == 'dark' ? Brightness.dark : Brightness.light,
      accent: AppAccent.fromId(j['accent'] as String?),
      language: AppLanguage.fromCode(j['language'] as String?),
      mode: ProcessingMode.fromId(j['mode'] as String?),
      whisperModelId: j['whisperModelId'] as String? ?? WhisperCatalog.defaultId,
      gemmaModelId: j['gemmaModelId'] as String? ?? GemmaCatalog.defaultId,
      provider: RemoteProviderId.fromId(j['provider'] as String?),
      remoteModelByProvider: remoteMap,
      autoDeleteAudio: j['autoDeleteAudio'] as bool? ?? true,
      onboarded: j['onboarded'] as bool? ?? false,
      hfToken: hfToken,
    );
  }
}
