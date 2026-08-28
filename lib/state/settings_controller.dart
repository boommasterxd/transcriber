import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_accent.dart';
import '../data/catalog/remote_catalog.dart';
import '../data/models/app_settings.dart';
import '../data/models/remote_provider.dart';
import '../data/models/transcription_language.dart';
import 'connections_controller.dart';
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

  Future<void> setThemeMode(ThemeMode mode) =>
      _persist(state.copyWith(themeMode: mode));

  Future<void> setTranscriptionLanguage(TranscriptionLanguage language) =>
      _persist(state.copyWith(transcriptionLanguage: language));

  Future<void> setAccent(AppAccent accent) =>
      _persist(state.copyWith(accent: accent));

  Future<void> setLanguage(AppLanguage language) =>
      _persist(state.copyWith(language: language));

  Future<void> setAsrProvider(RemoteProviderId provider) =>
      _persist(state.copyWith(asrProvider: provider));

  Future<void> setSummaryProvider(RemoteProviderId provider) =>
      _persist(state.copyWith(summaryProvider: provider));

  Future<void> setSummaryModel(RemoteProviderId provider, String modelId) {
    final map = Map<RemoteProviderId, String>.of(state.chatModelByProvider)
      ..[provider] = modelId;
    return _persist(state.copyWith(chatModelByProvider: map));
  }

  Future<void> setAsrModel(RemoteProviderId provider, String modelId) {
    final map = Map<RemoteProviderId, String>.of(state.asrModelByProvider)
      ..[provider] = modelId;
    return _persist(state.copyWith(asrModelByProvider: map));
  }

  Future<void> setAutoDelete(bool value) =>
      _persist(state.copyWith(autoDeleteAudio: value));

  Future<void> setSummarizeEnabled(bool value) =>
      _persist(state.copyWith(summarizeEnabled: value));

  Future<void> completeOnboarding() =>
      _persist(state.copyWith(onboarded: true));
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Active localized strings, derived from the language setting.
final stringsProvider = Provider<AppStrings>((ref) {
  final language = ref.watch(
    settingsControllerProvider.select((s) => s.language),
  );
  return AppStrings.of(language);
});

/// Status of the currently configured models for the home/sidebar chip.
class HomeModelStatus {
  const HomeModelStatus({required this.label, required this.warning});
  final String label;

  /// True when a selected cloud stage has no API key yet (needs attention).
  final bool warning;
}

/// Computes a state-aware label for the active cloud models and credentials.
final homeModelStatusProvider = Provider<HomeModelStatus>((ref) {
  final s = ref.watch(settingsControllerProvider);
  final connections = ref.watch(connectionsControllerProvider);
  final t = ref.watch(stringsProvider);

  String? issueFor(RemoteProviderId provider) {
    final connected = connections[provider] ?? false;
    return connected
        ? null
        : '${RemoteCatalog.provider(provider).name} · ${t.keyMissing}';
  }

  final asrIssue = issueFor(s.asrProvider);
  // When summarization is off, the summary model/key doesn't matter.
  final summaryIssue = s.summarizeEnabled ? issueFor(s.summaryProvider) : null;

  final issue = asrIssue ?? summaryIssue;
  if (issue != null) {
    return HomeModelStatus(label: issue, warning: true);
  }

  final asr = s.asrModelId(s.asrProvider);
  final summary = !s.summarizeEnabled
      ? t.summaryOff
      : s.summaryModelId(s.summaryProvider);
  return HomeModelStatus(label: '$asr · $summary', warning: false);
});
