import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/inference_backend.dart';
import 'package:transcriber/data/models/processing_mode.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcription_language.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/settings_controller.dart';

import 'state_test_fakes.dart';

void main() {
  final fixture = _SettingsFixture();
  setUp(fixture.setUp);
  tearDown(fixture.tearDown);
  _registerAppearanceTests(fixture);
  _registerModelTests(fixture);
  _registerPrivacyTests(fixture);
  _registerErrorTests(fixture);
}

void _registerAppearanceTests(_SettingsFixture fixture) {
  test(
    'seeds settings synchronously and persists appearance and language',
    () async {
      final controller = fixture.controller;

      expect(fixture.settings, AppSettings.initial());
      await controller.setThemeMode(ThemeMode.dark);
      await controller.setAccent(AppAccent.magenta);
      await controller.setLanguage(AppLanguage.en);
      await controller.setTranscriptionLanguage(TranscriptionLanguage.de);

      final state = fixture.settings;
      expect(state.themeMode, ThemeMode.dark);
      expect(state.accent, AppAccent.magenta);
      expect(state.language, AppLanguage.en);
      expect(state.transcriptionLanguage, TranscriptionLanguage.de);
      expect(fixture.repository.saved, hasLength(4));
    },
  );
}

void _registerModelTests(_SettingsFixture fixture) {
  test(
    'persists processing, model, backend, and provider selections',
    () async {
      final controller = fixture.controller;

      await controller.setAsrMode(ProcessingMode.cloud);
      await controller.setSummaryMode(ProcessingMode.cloud);
      await controller.setWhisperModel('whisper-custom');
      await controller.setGemmaModel('gemma-custom');
      await controller.setGemmaBackend(InferenceBackend.cpu);
      await controller.setAsrProvider(RemoteProviderId.google);
      await controller.setSummaryProvider(RemoteProviderId.openrouter);
      await controller.setAsrModel(RemoteProviderId.google, 'asr-model');
      await controller.setSummaryModel(
        RemoteProviderId.openrouter,
        'chat-model',
      );

      final state = fixture.settings;
      expect(state.asrMode, ProcessingMode.cloud);
      expect(state.summaryMode, ProcessingMode.cloud);
      expect(state.whisperModelId, 'whisper-custom');
      expect(state.gemmaModelId, 'gemma-custom');
      expect(state.gemmaBackend, InferenceBackend.cpu);
      expect(state.asrProvider, RemoteProviderId.google);
      expect(state.summaryProvider, RemoteProviderId.openrouter);
      expect(state.asrModelByProvider[RemoteProviderId.google], 'asr-model');
      expect(
        state.chatModelByProvider[RemoteProviderId.openrouter],
        'chat-model',
      );
      expect(fixture.repository.saved, hasLength(9));
    },
  );
}

void _registerPrivacyTests(_SettingsFixture fixture) {
  test(
    'clamps whisper threads and persists processing flags and token',
    () async {
      final controller = fixture.controller;

      await controller.setWhisperThreads(0);
      expect(fixture.settings.whisperThreads, 1);
      await controller.setWhisperThreads(99);
      expect(fixture.settings.whisperThreads, 8);
      await controller.setWhisperThreads(6);
      await controller.setAutoDelete(true);
      await controller.setSummarizeEnabled(false);
      await controller.setHfToken('hf-token');
      await controller.completeOnboarding();

      final state = fixture.settings;
      expect(state.whisperThreads, 6);
      expect(state.autoDeleteAudio, isTrue);
      expect(state.summarizeEnabled, isFalse);
      expect(state.hfToken, 'hf-token');
      expect(state.onboarded, isTrue);
    },
  );
}

void _registerErrorTests(_SettingsFixture fixture) {
  test('exposes persistence errors while retaining the new state', () async {
    fixture.repository.failOnSave = true;

    await expectLater(fixture.controller.setAutoDelete(true), throwsStateError);

    expect(fixture.settings.autoDeleteAudio, isTrue);
  });
}

class _SettingsFixture {
  late ProviderContainer container;
  late FakeSettingsRepository repository;

  Future<void> setUp() async {
    SharedPreferences.setMockInitialValues({});
    repository = FakeSettingsRepository(await SharedPreferences.getInstance());
    container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(AppSettings.initial()),
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  SettingsController get controller =>
      container.read(settingsControllerProvider.notifier);
  AppSettings get settings => container.read(settingsControllerProvider);

  void tearDown() => container.dispose();
}
