import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_accent.dart';
import '../data/catalog/gemma_catalog.dart';
import '../data/catalog/remote_catalog.dart';
import '../data/catalog/whisper_catalog.dart';
import '../data/models/app_settings.dart';
import '../data/models/inference_backend.dart';
import '../data/models/processing_mode.dart';
import '../data/models/remote_provider.dart';
import '../data/models/transcription_language.dart';
import 'connections_controller.dart';
import 'model_manager_controller.dart';
import 'providers.dart';

/// Holds and persists [AppSettings]. Seeded synchronously from
/// [initialSettingsProvider] so the first frame already has the right theme.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  Future<void> _persist(AppSettings next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }

  Future<void> setThemeMode(ThemeMode mode) => _persist(state.copyWith(themeMode: mode));

  Future<void> setTranscriptionLanguage(TranscriptionLanguage language) =>
      _persist(state.copyWith(transcriptionLanguage: language));

  Future<void> setAccent(AppAccent accent) => _persist(state.copyWith(accent: accent));

  Future<void> setLanguage(AppLanguage language) => _persist(state.copyWith(language: language));

  Future<void> setAsrMode(ProcessingMode mode) => _persist(state.copyWith(asrMode: mode));

  Future<void> setSummaryMode(ProcessingMode mode) => _persist(state.copyWith(summaryMode: mode));

  Future<void> setWhisperModel(String id) => _persist(state.copyWith(whisperModelId: id));

  Future<void> setGemmaModel(String id) => _persist(state.copyWith(gemmaModelId: id));

  Future<void> setGemmaBackend(InferenceBackend backend) =>
      _persist(state.copyWith(gemmaBackend: backend));

  Future<void> setWhisperThreads(int threads) =>
      _persist(state.copyWith(whisperThreads: threads.clamp(1, 8)));

  Future<void> setAsrProvider(RemoteProviderId provider) =>
      _persist(state.copyWith(asrProvider: provider));

  Future<void> setSummaryProvider(RemoteProviderId provider) =>
      _persist(state.copyWith(summaryProvider: provider));

  Future<void> setSummaryModel(RemoteProviderId provider, String modelId) {
    final map = Map<RemoteProviderId, String>.of(state.chatModelByProvider)..[provider] = modelId;
    return _persist(state.copyWith(chatModelByProvider: map));
  }

  Future<void> setAsrModel(RemoteProviderId provider, String modelId) {
    final map = Map<RemoteProviderId, String>.of(state.asrModelByProvider)..[provider] = modelId;
    return _persist(state.copyWith(asrModelByProvider: map));
  }

  Future<void> setAutoDelete(bool value) => _persist(state.copyWith(autoDeleteAudio: value));

  Future<void> setSummarizeEnabled(bool value) =>
      _persist(state.copyWith(summarizeEnabled: value));

  Future<void> setHfToken(String token) => _persist(state.copyWith(hfToken: token));

  Future<void> completeOnboarding() => _persist(state.copyWith(onboarded: true));
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Active localized strings, derived from the language setting.
final stringsProvider = Provider<AppStrings>((ref) {
  final language = ref.watch(settingsControllerProvider.select((s) => s.language));
  return AppStrings.of(language);
});

/// Status of the currently configured models for the home/sidebar chip.
class HomeModelStatus {
  const HomeModelStatus({required this.label, required this.fullyLocal, required this.warning});
  final String label;
  final bool fullyLocal;

  /// True when a selected cloud stage has no API key yet (needs attention).
  final bool warning;
}

/// Computes a state-aware label for the active models. Flags cloud stages
/// without an API key AND on-device stages whose selected model isn't
/// downloaded — so the chip never claims a model that can't actually run.
final homeModelStatusProvider = Provider<HomeModelStatus>((ref) {
  final s = ref.watch(settingsControllerProvider);
  final connections = ref.watch(connectionsControllerProvider);
  final manager = ref.watch(modelManagerControllerProvider);
  final t = ref.watch(stringsProvider);

  /// Returns an issue label for a stage, or null when it's ready.
  String? issueFor({
    required bool isLocal,
    required String localName,
    required bool localDownloaded,
    required RemoteProviderId provider,
  }) {
    if (isLocal) {
      return localDownloaded ? null : '$localName · ${t.notLoaded}';
    }
    final connected = connections[provider] ?? false;
    return connected ? null : '${RemoteCatalog.provider(provider).name} · ${t.keyMissing}';
  }

  final asrIssue = issueFor(
    isLocal: s.asrMode.isLocal,
    localName: WhisperCatalog.byId(s.whisperModelId).displayName,
    localDownloaded: manager.whisperStatus(s.whisperModelId).isDownloaded,
    provider: s.asrProvider,
  );
  // When summarization is off, the summary model/key doesn't matter.
  final summaryIssue = s.summarizeEnabled
      ? issueFor(
          isLocal: s.summaryMode.isLocal,
          localName: GemmaCatalog.byId(s.gemmaModelId).displayName,
          localDownloaded: manager.gemmaStatus(s.gemmaModelId).isDownloaded,
          provider: s.summaryProvider,
        )
      : null;

  final fullyLocal = s.asrMode.isLocal && (!s.summarizeEnabled || s.summaryMode.isLocal);

  final issue = asrIssue ?? summaryIssue;
  if (issue != null) {
    return HomeModelStatus(label: issue, fullyLocal: fullyLocal, warning: true);
  }

  final asr = s.asrMode.isLocal
      ? WhisperCatalog.byId(s.whisperModelId).displayName
      : s.asrModelId(s.asrProvider);
  final summary = !s.summarizeEnabled
      ? t.summaryOff
      : (s.summaryMode.isLocal
          ? GemmaCatalog.byId(s.gemmaModelId).displayName.split(' · ').first
          : s.summaryModelId(s.summaryProvider));
  return HomeModelStatus(label: '$asr · $summary', fullyLocal: fullyLocal, warning: false);
});
