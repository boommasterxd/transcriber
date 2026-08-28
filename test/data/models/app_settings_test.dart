import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/data/catalog/gemma_catalog.dart';
import 'package:transcriber/data/catalog/remote_catalog.dart';
import 'package:transcriber/data/catalog/whisper_catalog.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/inference_backend.dart';
import 'package:transcriber/data/models/processing_mode.dart';
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
    test('provides the documented local-first defaults', () {
      final settings = AppSettings.initial();

      _expectCoreDefaults(settings);
      expect(settings.whisperThreads, 4);
      expect(settings.asrProvider, RemoteProviderId.openai);
      expect(settings.summaryProvider, RemoteProviderId.anthropic);
      expect(settings.chatModelByProvider, isEmpty);
      expect(settings.asrModelByProvider, isEmpty);
      expect(settings.autoDeleteAudio, isFalse);
      expect(settings.summarizeEnabled, isTrue);
      expect(settings.onboarded, isFalse);
      expect(settings.hfToken, isEmpty);
      expect(settings.isFullyLocal, isTrue);
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
    test('replaces every configurable field', () {
      final original = AppSettings.initial();
      final chatModels = {RemoteProviderId.google: 'chat-model'};
      final asrModels = {RemoteProviderId.google: 'asr-model'};

      final changed = original.copyWith(
        themeMode: ThemeMode.dark,
        accent: AppAccent.magenta,
        language: AppLanguage.en,
        transcriptionLanguage: TranscriptionLanguage.en,
        asrMode: ProcessingMode.cloud,
        summaryMode: ProcessingMode.cloud,
        whisperModelId: 'small',
        gemmaModelId: 'gemma4_e2b',
        gemmaBackend: InferenceBackend.npu,
        whisperThreads: 8,
        asrProvider: RemoteProviderId.google,
        summaryProvider: RemoteProviderId.openrouter,
        chatModelByProvider: chatModels,
        asrModelByProvider: asrModels,
        autoDeleteAudio: true,
        summarizeEnabled: false,
        onboarded: true,
        hfToken: 'test-token',
      );

      expect(changed.themeMode, ThemeMode.dark);
      expect(changed.accent, AppAccent.magenta);
      expect(changed.language, AppLanguage.en);
      expect(changed.transcriptionLanguage, TranscriptionLanguage.en);
      expect(changed.asrMode, ProcessingMode.cloud);
      expect(changed.summaryMode, ProcessingMode.cloud);
      expect(changed.whisperModelId, 'small');
      expect(changed.gemmaModelId, 'gemma4_e2b');
      expect(changed.gemmaBackend, InferenceBackend.npu);
      expect(changed.whisperThreads, 8);
      expect(changed.asrProvider, RemoteProviderId.google);
      expect(changed.summaryProvider, RemoteProviderId.openrouter);
      expect(changed.chatModelByProvider, chatModels);
      expect(changed.asrModelByProvider, asrModels);
      expect(changed.autoDeleteAudio, isTrue);
      expect(changed.summarizeEnabled, isFalse);
      expect(changed.onboarded, isTrue);
      expect(changed.hfToken, 'test-token');
      expect(changed.isFullyLocal, isFalse);
      expect(changed.summaryModelId(RemoteProviderId.google), 'chat-model');
      expect(changed.asrModelId(RemoteProviderId.google), 'asr-model');
    });

    test('preserves every field when no replacement is supplied', () {
      final original = _completeSettings();
      final copied = original.copyWith();

      expect(copied.toJson(), original.toJson());
      expect(copied.hfToken, original.hfToken);
      expect(copied.chatModelByProvider, same(original.chatModelByProvider));
      expect(copied.asrModelByProvider, same(original.asrModelByProvider));
    });
  });
}

void _testJsonRoundTrip() {
  group('AppSettings JSON', () {
    test('round-trips all persisted values and injects the secure token', () {
      final original = _completeSettings();
      final json = original.toJson();

      expect(json, isNot(contains('hfToken')));
      final restored = AppSettings.fromJson(json, hfToken: 'restored-token');

      expect(restored.toJson(), json);
      expect(restored.hfToken, 'restored-token');
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
    test('uses independent stage modes over the legacy shared mode', () {
      final settings = AppSettings.fromJson({
        'mode': 'remote',
        'asrMode': 'local',
        'summaryMode': 'remote',
      }, hfToken: '');

      expect(settings.asrMode, ProcessingMode.onDevice);
      expect(settings.summaryMode, ProcessingMode.cloud);
    });

    test('migrates the legacy shared remote mode to both stages', () {
      final settings = AppSettings.fromJson({'mode': 'remote'}, hfToken: '');

      expect(settings.asrMode, ProcessingMode.cloud);
      expect(settings.summaryMode, ProcessingMode.cloud);
      expect(settings.isFullyLocal, isFalse);
    });

    test('migrates legacy brightness when theme mode is absent', () {
      expect(
        AppSettings.fromJson({'brightness': 'dark'}, hfToken: '').themeMode,
        ThemeMode.dark,
      );
      expect(
        AppSettings.fromJson({'brightness': 'light'}, hfToken: '').themeMode,
        ThemeMode.light,
      );
      expect(
        AppSettings.fromJson({'brightness': 'unknown'}, hfToken: '').themeMode,
        ThemeMode.system,
      );
    });

    test('prefers valid theme mode and falls back from invalid theme mode', () {
      for (final mode in ThemeMode.values) {
        final settings = AppSettings.fromJson({
          'themeMode': mode.name,
          'brightness': 'dark',
        }, hfToken: '');
        expect(settings.themeMode, mode);
      }

      final invalid = AppSettings.fromJson({
        'themeMode': 'sepia',
        'brightness': 'dark',
      }, hfToken: '');
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
        'asrMode': 'invalid',
        'summaryMode': 'invalid',
        'gemmaBackend': 'invalid',
        'asrProvider': 'anthropic',
        'summaryProvider': 'invalid',
      }, hfToken: 'secure');

      _expectCoreDefaults(settings);
      expect(settings.asrProvider, RemoteProviderId.openai);
      expect(settings.summaryProvider, RemoteProviderId.anthropic);
      expect(settings.hfToken, 'secure');
    });

    test('normalizes numeric thread counts and stringifies map values', () {
      final settings = AppSettings.fromJson({
        'whisperThreads': 3.9,
        'chatModelByProvider': {'google': 42},
        'asrModelByProvider': {'openai': true},
      }, hfToken: '');

      expect(settings.whisperThreads, 3);
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
  expect(settings.asrMode, ProcessingMode.onDevice);
  expect(settings.summaryMode, ProcessingMode.onDevice);
  expect(settings.whisperModelId, WhisperCatalog.defaultId);
  expect(settings.gemmaModelId, GemmaCatalog.defaultId);
  expect(settings.gemmaBackend, InferenceBackend.auto);
}

AppSettings _completeSettings() => const AppSettings(
  themeMode: ThemeMode.light,
  accent: AppAccent.amber,
  language: AppLanguage.en,
  transcriptionLanguage: TranscriptionLanguage.de,
  asrMode: ProcessingMode.cloud,
  summaryMode: ProcessingMode.onDevice,
  whisperModelId: 'medium',
  gemmaModelId: 'deepseek_r1',
  gemmaBackend: InferenceBackend.cpu,
  whisperThreads: 6,
  asrProvider: RemoteProviderId.google,
  summaryProvider: RemoteProviderId.openrouter,
  chatModelByProvider: {RemoteProviderId.google: 'gemini-custom'},
  asrModelByProvider: {RemoteProviderId.openai: 'transcribe-custom'},
  autoDeleteAudio: true,
  summarizeEnabled: false,
  onboarded: true,
  hfToken: 'not-persisted',
);
