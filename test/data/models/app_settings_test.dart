import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/data/catalog/remote_catalog.dart';
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
        themeMode: ThemeMode.dark,
        accent: AppAccent.magenta,
        language: AppLanguage.en,
        transcriptionLanguage: TranscriptionLanguage.en,
        asrProvider: RemoteProviderId.openai,
        summaryProvider: RemoteProviderId.google,
        chatModelByProvider: chatModels,
        asrModelByProvider: asrModels,
        autoDeleteAudio: true,
        summarizeEnabled: false,
        onboarded: true,
      );

      expect(changed.themeMode, ThemeMode.dark);
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
      final copied = original.copyWith();

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
        ThemeMode.dark,
      );
      expect(
        AppSettings.fromJson({'brightness': 'light'}).themeMode,
        ThemeMode.light,
      );
      expect(
        AppSettings.fromJson({'brightness': 'unknown'}).themeMode,
        ThemeMode.system,
      );
    });

    test('prefers valid theme mode and falls back from invalid theme mode', () {
      for (final mode in ThemeMode.values) {
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
      expect(invalid.themeMode, ThemeMode.system);
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
  expect(settings.themeMode, ThemeMode.system);
  expect(settings.accent, AppAccent.blue);
  expect(settings.language, AppLanguage.de);
  expect(settings.transcriptionLanguage, TranscriptionLanguage.auto);
}

AppSettings _completeSettings() => const AppSettings(
  themeMode: ThemeMode.light,
  accent: AppAccent.amber,
  language: AppLanguage.en,
  transcriptionLanguage: TranscriptionLanguage.de,
  asrProvider: RemoteProviderId.openai,
  summaryProvider: RemoteProviderId.google,
  chatModelByProvider: {RemoteProviderId.google: 'gemini-custom'},
  asrModelByProvider: {RemoteProviderId.openai: 'transcribe-custom'},
  autoDeleteAudio: true,
  summarizeEnabled: false,
  onboarded: true,
);
