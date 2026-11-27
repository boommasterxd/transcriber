import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_strings.dart';
import '../data/catalog/remote_catalog.dart';
import '../data/models/app_accent.dart';
import '../data/models/app_settings.dart';
import '../data/models/remote_provider.dart';
import '../data/models/transcription_language.dart';
import 'connections_controller.dart';
import 'providers.dart';

/// Holds and persists [AppSettings]. Seeded synchronously from
/// [initialSettingsProvider] so the first frame already has the right theme.
class SettingsController extends Notifier<AppSettings> {
  Future<void> _pending = Future.value();
  StreamSubscription<Object?>? _updates;
  bool _closing = false;

  @override
  AppSettings build() {
    final initial = ref.watch(initialSettingsProvider);
    final repository = ref.watch(settingsRepositoryProvider);
    final updates = repository.updates.listen((_) {
      if (!_closing) unawaited(refresh().catchError((Object _) {}));
    }, onError: (Object _) {});
    _updates = updates;
    ref.onDispose(() => unawaited(updates.cancel()));
    return initial;
  }

  @override
  bool updateShouldNotify(AppSettings previous, AppSettings next) =>
      _storedValues(previous) != _storedValues(next);

  Object _storedValues(AppSettings settings) => (
    settings.themeMode,
    settings.accent,
    settings.language,
    settings.transcriptionLanguage,
    settings.asrProvider,
    settings.asrModelId(settings.asrProvider),
    settings.summaryProvider,
    settings.summaryModelId(settings.summaryProvider),
    settings.summarizeEnabled,
    settings.autoDeleteAudio,
    settings.onboarded,
  );

  /// Resolves persisted settings after earlier writes from this engine settle.
  Future<AppSettings> readCurrent() => _enqueue(() async {
    if (_closing || !ref.mounted) {
      throw StateError('Settings are no longer available.');
    }
    final settings = await ref.read(settingsRepositoryProvider).load();
    if (ref.mounted && !_closing) state = settings;
    return settings;
  });

  Future<void> refresh() async {
    await readCurrent();
  }

  /// Stops accepting changes and drains the settings work before closing Drift.
  Future<void> close() async {
    _closing = true;
    await _updates?.cancel();
    await _pending;
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> _persist(AppSettings Function(AppSettings) change) {
    if (_closing) return Future.value(false);
    return _enqueue(() async {
      if (!ref.mounted) return false;
      try {
        final saved = await ref.read(settingsRepositoryProvider).update(change);
        if (ref.mounted && !_closing) state = saved;
        return true;
      } on _StaleModelChoice {
        return false;
      } catch (_) {
        if (ref.mounted && !_closing) {
          ref.invalidate(settingsWriteErrorProvider);
        }
        return false;
      }
    });
  }

  Future<bool> setThemeMode(AppThemeMode mode) => _persist(
    (current) => current.copyWith(
      appearance: current.appearance.copyWith(themeMode: mode),
    ),
  );

  Future<bool> setTranscriptionLanguage(TranscriptionLanguage language) =>
      _persist(
        (current) => current.copyWith(
          transcription: current.transcription.copyWith(language: language),
        ),
      );

  Future<bool> setAccent(AppAccent accent) => _persist(
    (current) => current.copyWith(
      appearance: current.appearance.copyWith(accent: accent),
    ),
  );

  Future<bool> setLanguage(AppLanguage language) => _persist(
    (current) => current.copyWith(
      appearance: current.appearance.copyWith(language: language),
    ),
  );

  Future<bool> selectConnectedProviders(List<RemoteProviderId> connected) =>
      _persist(
        (current) => current.copyWith(
          transcription: current.transcription.copyWith(
            provider: connected.contains(current.asrProvider)
                ? current.asrProvider
                : connected.first,
          ),
          summary: current.summary.copyWith(
            provider: connected.contains(current.summaryProvider)
                ? current.summaryProvider
                : connected.first,
          ),
        ),
      );

  /// Saves a confirmed provider and model together without an intermediate choice.
  Future<bool> setAsrSelection(
    RemoteProviderId provider,
    String modelId, {
    int? credentialRevision,
  }) => _persist((current) {
    _requireCurrentCredential(provider, credentialRevision);
    return current.copyWith(
      transcription: current.transcription.copyWith(
        provider: provider,
        models: {provider: modelId},
      ),
    );
  });

  Future<bool> setSummarySelection(
    RemoteProviderId provider,
    String modelId, {
    int? credentialRevision,
  }) => _persist((current) {
    _requireCurrentCredential(provider, credentialRevision);
    return current.copyWith(
      summary: current.summary.copyWith(
        provider: provider,
        models: {provider: modelId},
      ),
    );
  });

  void _requireCurrentCredential(RemoteProviderId provider, int? revision) {
    if (revision == null) return;
    final connections = ref.read(connectionsControllerProvider.notifier);
    if (!connections.isConnected(provider) ||
        connections.catalogRevision(provider) != revision) {
      throw const _StaleModelChoice();
    }
  }

  Future<bool> setAutoDelete(bool value) =>
      _persist((current) => current.copyWith(autoDeleteAudio: value));

  Future<bool> setSummarizeEnabled(bool value) => _persist(
    (current) =>
        current.copyWith(summary: current.summary.copyWith(enabled: value)),
  );

  Future<bool> completeOnboarding() =>
      _persist((current) => current.copyWith(onboarded: true));
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

final class _StaleModelChoice implements Exception {
  const _StaleModelChoice();
}

final settingsWriteErrorProvider = Provider<Object>((ref) => Object());

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
