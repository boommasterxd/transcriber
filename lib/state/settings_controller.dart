import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_accent.dart';
import '../data/models/app_settings.dart';
import '../data/models/processing_mode.dart';
import '../data/models/remote_provider.dart';
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

  Future<void> setBrightness(Brightness brightness) =>
      _persist(state.copyWith(brightness: brightness));

  Future<void> setAccent(AppAccent accent) => _persist(state.copyWith(accent: accent));

  Future<void> setLanguage(AppLanguage language) => _persist(state.copyWith(language: language));

  Future<void> setMode(ProcessingMode mode) => _persist(state.copyWith(mode: mode));

  Future<void> setWhisperModel(String id) => _persist(state.copyWith(whisperModelId: id));

  Future<void> setGemmaModel(String id) => _persist(state.copyWith(gemmaModelId: id));

  Future<void> setProvider(RemoteProviderId provider) => _persist(state.copyWith(provider: provider));

  Future<void> setRemoteModel(RemoteProviderId provider, String modelId) {
    final map = Map<RemoteProviderId, String>.of(state.remoteModelByProvider)..[provider] = modelId;
    return _persist(state.copyWith(remoteModelByProvider: map));
  }

  Future<void> setAutoDelete(bool value) => _persist(state.copyWith(autoDeleteAudio: value));

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
