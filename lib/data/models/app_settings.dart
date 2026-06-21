import 'package:flutter/material.dart' show ThemeMode;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_accent.dart';
import '../catalog/remote_catalog.dart';
import '../catalog/gemma_catalog.dart';
import '../catalog/whisper_catalog.dart';
import 'inference_backend.dart';
import 'processing_mode.dart';
import 'remote_provider.dart';
import 'transcription_language.dart';

/// Immutable snapshot of all user preferences.
///
/// Transcription and summarization are configured **independently** — each can
/// run on-device or via a cloud provider, in any combination. Cloud model ids
/// are the raw identifiers chosen from each provider's live model list. API keys
/// are stored separately in secure storage.
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.accent,
    required this.language,
    required this.transcriptionLanguage,
    required this.asrMode,
    required this.summaryMode,
    required this.whisperModelId,
    required this.gemmaModelId,
    required this.gemmaBackend,
    required this.whisperThreads,
    required this.asrProvider,
    required this.summaryProvider,
    required this.chatModelByProvider,
    required this.asrModelByProvider,
    required this.autoDeleteAudio,
    required this.summarizeEnabled,
    required this.onboarded,
    required this.hfToken,
  });

  /// System / Light / Dark — `system` follows the OS setting.
  final ThemeMode themeMode;
  final AppAccent accent;
  final AppLanguage language;
  final TranscriptionLanguage transcriptionLanguage;

  final ProcessingMode asrMode;
  final ProcessingMode summaryMode;

  final String whisperModelId;
  final String gemmaModelId;

  /// Preferred compute backend for the on-device summary model.
  final InferenceBackend gemmaBackend;

  /// CPU thread count for on-device Whisper transcription (whisper.cpp).
  final int whisperThreads;

  final RemoteProviderId asrProvider;
  final RemoteProviderId summaryProvider;

  /// Selected cloud model id per provider (chat/summary and ASR respectively).
  final Map<RemoteProviderId, String> chatModelByProvider;
  final Map<RemoteProviderId, String> asrModelByProvider;

  final bool autoDeleteAudio;

  /// When false, processing stops after transcription — no AI summary is made.
  final bool summarizeEnabled;
  final bool onboarded;
  final String hfToken;

  bool get isFullyLocal => asrMode.isLocal && summaryMode.isLocal;

  String summaryModelId(RemoteProviderId p) =>
      chatModelByProvider[p] ?? RemoteCatalog.chatDefault(p);

  String asrModelId(RemoteProviderId p) =>
      asrModelByProvider[p] ?? RemoteCatalog.asrDefault(p);

  factory AppSettings.initial() => const AppSettings(
        themeMode: ThemeMode.system,
        accent: AppAccent.blue,
        language: AppLanguage.de,
        transcriptionLanguage: TranscriptionLanguage.auto,
        asrMode: ProcessingMode.onDevice,
        summaryMode: ProcessingMode.onDevice,
        whisperModelId: WhisperCatalog.defaultId,
        gemmaModelId: GemmaCatalog.defaultId,
        gemmaBackend: InferenceBackend.auto,
        whisperThreads: 4,
        asrProvider: RemoteProviderId.openai,
        summaryProvider: RemoteProviderId.anthropic,
        chatModelByProvider: {},
        asrModelByProvider: {},
        autoDeleteAudio: false,
        summarizeEnabled: true,
        onboarded: false,
        hfToken: '',
      );

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppAccent? accent,
    AppLanguage? language,
    TranscriptionLanguage? transcriptionLanguage,
    ProcessingMode? asrMode,
    ProcessingMode? summaryMode,
    String? whisperModelId,
    String? gemmaModelId,
    InferenceBackend? gemmaBackend,
    int? whisperThreads,
    RemoteProviderId? asrProvider,
    RemoteProviderId? summaryProvider,
    Map<RemoteProviderId, String>? chatModelByProvider,
    Map<RemoteProviderId, String>? asrModelByProvider,
    bool? autoDeleteAudio,
    bool? summarizeEnabled,
    bool? onboarded,
    String? hfToken,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        accent: accent ?? this.accent,
        language: language ?? this.language,
        transcriptionLanguage: transcriptionLanguage ?? this.transcriptionLanguage,
        asrMode: asrMode ?? this.asrMode,
        summaryMode: summaryMode ?? this.summaryMode,
        whisperModelId: whisperModelId ?? this.whisperModelId,
        gemmaModelId: gemmaModelId ?? this.gemmaModelId,
        gemmaBackend: gemmaBackend ?? this.gemmaBackend,
        whisperThreads: whisperThreads ?? this.whisperThreads,
        asrProvider: asrProvider ?? this.asrProvider,
        summaryProvider: summaryProvider ?? this.summaryProvider,
        chatModelByProvider: chatModelByProvider ?? this.chatModelByProvider,
        asrModelByProvider: asrModelByProvider ?? this.asrModelByProvider,
        autoDeleteAudio: autoDeleteAudio ?? this.autoDeleteAudio,
        summarizeEnabled: summarizeEnabled ?? this.summarizeEnabled,
        onboarded: onboarded ?? this.onboarded,
        hfToken: hfToken ?? this.hfToken,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'accent': accent.id,
        'language': language.code,
        'transcriptionLanguage': transcriptionLanguage.code,
        'asrMode': asrMode.id,
        'summaryMode': summaryMode.id,
        'whisperModelId': whisperModelId,
        'gemmaModelId': gemmaModelId,
        'gemmaBackend': gemmaBackend.id,
        'whisperThreads': whisperThreads,
        'asrProvider': asrProvider.id,
        'summaryProvider': summaryProvider.id,
        'chatModelByProvider': chatModelByProvider.map((k, v) => MapEntry(k.id, v)),
        'asrModelByProvider': asrModelByProvider.map((k, v) => MapEntry(k.id, v)),
        'autoDeleteAudio': autoDeleteAudio,
        'summarizeEnabled': summarizeEnabled,
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
      themeMode: _themeModeFrom(j),
      accent: AppAccent.fromId(j['accent'] as String?),
      language: AppLanguage.fromCode(j['language'] as String?),
      transcriptionLanguage: TranscriptionLanguage.fromCode(j['transcriptionLanguage'] as String?),
      asrMode: mode('asrMode'),
      summaryMode: mode('summaryMode'),
      whisperModelId: j['whisperModelId'] as String? ?? WhisperCatalog.defaultId,
      gemmaModelId: j['gemmaModelId'] as String? ?? GemmaCatalog.defaultId,
      gemmaBackend: InferenceBackend.fromId(j['gemmaBackend'] as String?),
      whisperThreads: (j['whisperThreads'] as num?)?.toInt() ?? 4,
      asrProvider: _asrProviderFromId(j['asrProvider'] as String?),
      summaryProvider: RemoteProviderId.fromId(j['summaryProvider'] as String?),
      chatModelByProvider: parseMap('chatModelByProvider'),
      asrModelByProvider: parseMap('asrModelByProvider'),
      autoDeleteAudio: j['autoDeleteAudio'] as bool? ?? false,
      summarizeEnabled: j['summarizeEnabled'] as bool? ?? true,
      onboarded: j['onboarded'] as bool? ?? false,
      hfToken: hfToken,
    );
  }

  static ThemeMode _themeModeFrom(Map<String, dynamic> j) {
    final raw = j['themeMode'] as String?;
    if (raw != null) {
      return ThemeMode.values.firstWhere((m) => m.name == raw, orElse: () => ThemeMode.system);
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
    return RemoteCatalog.asrProviders.contains(p) ? p : RemoteProviderId.openai;
  }
}
