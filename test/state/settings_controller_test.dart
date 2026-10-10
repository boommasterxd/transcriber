import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
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
  test('applies transcription provider and model with one save', () async {
    final before = fixture.settings;
    await fixture.controller.setAsrSelection(
      RemoteProviderId.openai,
      'new-api-transcription',
    );
    final saved = fixture.repository.saved.single;
    expect(saved.asrProvider, RemoteProviderId.openai);
    expect(saved.asrModelId(RemoteProviderId.openai), 'new-api-transcription');
    expect(saved.summaryProvider, before.summaryProvider);
    expect(saved.chatModelByProvider, before.chatModelByProvider);
    expect(
      saved.asrModelId(RemoteProviderId.google),
      before.asrModelId(RemoteProviderId.google),
    );
  });
  test('applies summary provider and model with one save', () async {
    final before = fixture.settings;
    await fixture.controller.setSummarySelection(
      RemoteProviderId.openai,
      'new-api-summary',
    );
    final saved = fixture.repository.saved.single;
    expect(saved.summaryProvider, RemoteProviderId.openai);
    expect(saved.summaryModelId(RemoteProviderId.openai), 'new-api-summary');
    expect(saved.asrProvider, before.asrProvider);
    expect(saved.asrModelByProvider, before.asrModelByProvider);
    expect(
      saved.summaryModelId(RemoteProviderId.google),
      before.summaryModelId(RemoteProviderId.google),
    );
  });
  test(
    'persists cloud provider and model selections for both stages',
    () async {
      final controller = fixture.controller;

      await controller.setAsrProvider(RemoteProviderId.openai);
      await controller.setSummaryProvider(RemoteProviderId.google);
      await controller.setAsrModel(RemoteProviderId.openai, 'asr-model');
      await controller.setSummaryModel(RemoteProviderId.google, 'chat-model');

      final state = fixture.settings;
      expect(state.asrProvider, RemoteProviderId.openai);
      expect(state.summaryProvider, RemoteProviderId.google);
      expect(state.asrModelByProvider[RemoteProviderId.openai], 'asr-model');
      expect(state.chatModelByProvider[RemoteProviderId.google], 'chat-model');
      expect(fixture.repository.saved, hasLength(4));
    },
  );
}

void _registerPrivacyTests(_SettingsFixture fixture) {
  test('persists audio retention, summary, and onboarding flags', () async {
    final controller = fixture.controller;

    await controller.setAutoDelete(true);
    await controller.setSummarizeEnabled(false);
    await controller.completeOnboarding();

    final state = fixture.settings;
    expect(state.autoDeleteAudio, isTrue);
    expect(state.summarizeEnabled, isFalse);
    expect(state.onboarded, isTrue);
  });
}

void _registerErrorTests(_SettingsFixture fixture) {
  test('exposes persistence errors while retaining the new state', () async {
    fixture.repository.failOnSave = true;

    await expectLater(fixture.controller.setAutoDelete(true), throwsStateError);

    expect(fixture.settings.autoDeleteAudio, isTrue);
  });
}

class _SettingsFixture {
  late AppDatabase database;
  late ProviderContainer container;
  late FakeSettingsRepository repository;

  void setUp() {
    database = createTestDatabase();
    repository = FakeSettingsRepository(database);
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

  Future<void> tearDown() async {
    container.dispose();
    await database.close();
  }
}
