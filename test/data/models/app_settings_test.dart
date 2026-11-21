import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/catalog/remote_catalog.dart';
import 'package:transcriber/data/models/app_accent.dart';
import 'package:transcriber/data/models/app_language.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcription_language.dart';

void main() {
  _testInitialSettings();
  _testCopyWith();
  _testJsonRoundTrip();
  _testLegacyJson();
  _testJsonFallbacks();
}

void _testInitialSettings() {
  group('AppSettings.initial', () {
    test('provides the documented cloud defaults', () {
      final settings = AppSettings.initial();

      _expectCoreDefaults(settings);
      expect(settings.asrProvider, RemoteProviderId.google);
      expect(settings.summaryProvider, RemoteProviderId.google);
      expect(settings.chatModelByProvider, isEmpty);
      expect(settings.asrModelByProvider, isEmpty);
      expect(settings.autoDeleteAudio, isFalse);
      expect(settings.summarizeEnabled, isTrue);
      expect(settings.onboarded, isFalse);
    });

    test('falls back to catalog model defaults for unselected providers', () {
      final settings = AppSettings.initial();

      for (final provider in RemoteProviderId.values) {
        expect(
          settings.summaryModelId(provider),
          RemoteCatalog.chatDefault(provider),
        );
        expect(
          settings.asrModelId(provider),
          RemoteCatalog.asrDefault(provider),
        );
      }
    });
  });
}

void _testCopyWith() {
  group('AppSettings.copyWith', () {
    test('replaces every configurable cloud field', () {
      final original = AppSettings.initial();
      final chatModels = {RemoteProviderId.google: 'chat-model'};
      final asrModels = {RemoteProviderId.openai: 'asr-model'};

      final changed = original.copyWith(
        appearance: original.appearance.copyWith(
          themeMode: AppThemeMode.dark,
          accent: AppAccent.magenta,
          language: AppLanguage.en,
        ),
        transcription: original.transcription.copyWith(
          language: TranscriptionLanguage.en,
          provider: RemoteProviderId.openai,
          models: asrModels,
        ),
        summary: original.summary.copyWith(
          provider: RemoteProviderId.google,
          models: chatModels,
          enabled: false,
        ),
        autoDeleteAudio: true,
        onboarded: true,
      );

      expect(changed.themeMode, AppThemeMode.dark);
      expect(changed.accent, AppAccent.magenta);
      expect(changed.language, AppLanguage.en);
      expect(changed.transcriptionLanguage, TranscriptionLanguage.en);
      expect(changed.asrProvider, RemoteProviderId.openai);
      expect(changed.summaryProvider, RemoteProviderId.google);
      expect(changed.chatModelByProvider, chatModels);
      expect(changed.asrModelByProvider, asrModels);
      expect(changed.autoDeleteAudio, isTrue);
      expect(changed.summarizeEnabled, isFalse);
      expect(changed.onboarded, isTrue);
      expect(changed.summaryModelId(RemoteProviderId.google), 'chat-model');
      expect(changed.asrModelId(RemoteProviderId.openai), 'asr-model');
    });

    test('preserves every field when no replacement is supplied', () {
      final original = _completeSettings();
      final unchanged = original.copyWith();
      final copied = original.copyWith(
        appearance: original.appearance.copyWith(),
        transcription: original.transcription.copyWith(),
        summary: original.summary.copyWith(),
      );

      expect(unchanged.toJson(), original.toJson());
      expect(unchanged.appearance, same(original.appearance));
      expect(unchanged.transcription, same(original.transcription));
      expect(unchanged.summary, same(original.summary));
      expect(copied.toJson(), original.toJson());
      expect(copied.chatModelByProvider, same(original.chatModelByProvider));
      expect(copied.asrModelByProvider, same(original.asrModelByProvider));
    });
  });
}

void _testJsonRoundTrip() {
  group('AppSettings JSON', () {
    test('round-trips all persisted cloud settings', () {
      final original = _completeSettings();
      final json = original.toJson();

      final restored = AppSettings.fromJson(json);

      expect(json, {
        'themeMode': 'light',
        'accent': 'amber',
        'language': 'en',
        'transcriptionLanguage': 'de',
        'asrProvider': 'openai',
        'summaryProvider': 'google',
        'chatModelByProvider': {'google': 'gemini-custom'},
        'asrModelByProvider': {'openai': 'transcribe-custom'},
        'autoDeleteAudio': true,
        'summarizeEnabled': false,
        'onboarded': true,
      });
      expect(restored.toJson(), json);
      expect(restored.chatModelByProvider, {
        RemoteProviderId.google: 'gemini-custom',
      });
      expect(restored.asrModelByProvider, {
        RemoteProviderId.openai: 'transcribe-custom',
      });
    });
  });
}

void _testLegacyJson() {
  group('AppSettings legacy JSON', () {
    test('migrates legacy brightness when theme mode is absent', () {
      expect(
        AppSettings.fromJson({'brightness': 'dark'}).themeMode,
        AppThemeMode.dark,
      );
      expect(
        AppSettings.fromJson({'brightness': 'light'}).themeMode,
        AppThemeMode.light,
      );
      expect(
        AppSettings.fromJson({'brightness': 'unknown'}).themeMode,
        AppThemeMode.system,
      );
    });

    test('prefers valid theme mode and falls back from invalid theme mode', () {
      for (final mode in AppThemeMode.values) {
        final settings = AppSettings.fromJson({
          'themeMode': mode.name,
          'brightness': 'dark',
        });
        expect(settings.themeMode, mode);
      }

      final invalid = AppSettings.fromJson({
        'themeMode': 'sepia',
        'brightness': 'dark',
      });
      expect(invalid.themeMode, AppThemeMode.system);
    });
  });
}

void _testJsonFallbacks() {
  group('AppSettings JSON fallbacks', () {
    test('uses safe defaults for missing and invalid enum values', () {
      final settings = AppSettings.fromJson({
        'accent': 'invalid',
        'language': 'invalid',
        'transcriptionLanguage': 'invalid',
        'asrProvider': 'unsupported',
        'summaryProvider': 'unsupported',
      });

      _expectCoreDefaults(settings);
      expect(settings.asrProvider, RemoteProviderId.google);
      expect(settings.summaryProvider, RemoteProviderId.google);
    });

    test('normalizes map values to strings', () {
      final settings = AppSettings.fromJson({
        'chatModelByProvider': {'google': 42},
        'asrModelByProvider': {'openai': true},
      });

      expect(settings.chatModelByProvider[RemoteProviderId.google], '42');
      expect(settings.asrModelByProvider[RemoteProviderId.openai], 'true');
    });
  });
}

void _expectCoreDefaults(AppSettings settings) {
  expect(settings.themeMode, AppThemeMode.system);
  expect(settings.accent, AppAccent.blue);
  expect(settings.language, AppLanguage.de);
  expect(settings.transcriptionLanguage, TranscriptionLanguage.auto);
}

AppSettings _completeSettings() => const AppSettings(
  appearance: AppearanceSettings(
    themeMode: AppThemeMode.light,
    accent: AppAccent.amber,
    language: AppLanguage.en,
  ),
  transcription: TranscriptionSettings(
    language: TranscriptionLanguage.de,
    provider: RemoteProviderId.openai,
    models: {RemoteProviderId.openai: 'transcribe-custom'},
  ),
  summary: SummarySettings(
    provider: RemoteProviderId.google,
    models: {RemoteProviderId.google: 'gemini-custom'},
    enabled: false,
  ),
  autoDeleteAudio: true,
  onboarded: true,
);
