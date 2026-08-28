import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/processing_mode.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/repositories/settings_repository.dart';

void main() {
  final context = _RepositoryTestContext();

  group('SettingsRepository', () {
    setUp(context.setUp);
    _registerLoadTests(context);
    _registerSaveTest(context);
    _registerApiKeyTests(context);
  });
}

void _registerLoadTests(_RepositoryTestContext context) {
  test('loads initial settings when plain persistence is empty', () async {
    FlutterSecureStorage.setMockInitialValues({'hf_token': 'stored-token'});

    final loaded = await context.repository.load();

    expect(loaded.toJson(), AppSettings.initial().toJson());
    expect(loaded.hfToken, 'stored-token');
  });

  test(
    'loads valid settings and obtains the token from secure storage',
    () async {
      final expected = _customSettings(hfToken: 'must-not-be-in-json');
      SharedPreferences.setMockInitialValues({
        'app_settings': jsonEncode(expected.toJson()),
      });
      FlutterSecureStorage.setMockInitialValues({'hf_token': 'secure-token'});
      context.preferences = await SharedPreferences.getInstance();
      context.repository = SettingsRepository(
        context.preferences,
        secureStorage: context.secureStorage,
      );

      final loaded = await context.repository.load();

      expect(loaded.toJson(), expected.toJson());
      expect(loaded.hfToken, 'secure-token');
    },
  );

  test('falls back safely for malformed plain persistence', () async {
    FlutterSecureStorage.setMockInitialValues({'hf_token': 'secure-token'});

    for (final malformed in <String>[
      'not-json',
      jsonEncode(['not', 'an', 'object']),
      jsonEncode({'chatModelByProvider': 'not-a-map'}),
    ]) {
      await context.preferences.setString('app_settings', malformed);

      final loaded = await context.repository.load();

      expect(loaded.toJson(), AppSettings.initial().toJson());
      expect(loaded.hfToken, 'secure-token');
    }
  });
}

void _registerSaveTest(_RepositoryTestContext context) {
  test('saves settings while keeping the token out of plain storage', () async {
    final settings = _customSettings(hfToken: 'private-token');

    await context.repository.save(settings);

    final plainJson = context.preferences.getString('app_settings')!;
    expect(jsonDecode(plainJson), settings.toJson());
    expect(plainJson, isNot(contains('private-token')));
    expect(context.preferences.getKeys(), isNot(contains('hf_token')));
    expect(await context.secureStorage.read(key: 'hf_token'), 'private-token');
  });
}

void _registerApiKeyTests(_RepositoryTestContext context) {
  test('supports the complete isolated API key lifecycle', () async {
    expect(await context.repository.apiKey(RemoteProviderId.openai), isNull);

    await context.repository.setApiKey(RemoteProviderId.openai, 'first-key');
    await context.repository.setApiKey(RemoteProviderId.anthropic, 'other-key');
    await context.repository.setApiKey(RemoteProviderId.openai, 'updated-key');

    expect(
      await context.repository.apiKey(RemoteProviderId.openai),
      'updated-key',
    );
    expect(
      await context.repository.apiKey(RemoteProviderId.anthropic),
      'other-key',
    );
    expect(context.preferences.getKeys(), isEmpty);

    await context.repository.deleteApiKey(RemoteProviderId.openai);

    expect(await context.repository.apiKey(RemoteProviderId.openai), isNull);
    expect(
      await context.repository.apiKey(RemoteProviderId.anthropic),
      'other-key',
    );
  });

  test('reports only providers with non-empty API keys as connected', () async {
    FlutterSecureStorage.setMockInitialValues({
      'api_key_anthropic': 'anthropic-key',
      'api_key_openai': '',
      'api_key_openrouter': 'openrouter-key',
    });

    final connected = await context.repository.connectedProviders();

    expect(connected, {
      RemoteProviderId.anthropic: true,
      RemoteProviderId.openai: false,
      RemoteProviderId.google: false,
      RemoteProviderId.openrouter: true,
    });
  });
}

class _RepositoryTestContext {
  final secureStorage = const FlutterSecureStorage();
  late SharedPreferences preferences;
  late SettingsRepository repository;

  Future<void> setUp() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = SettingsRepository(preferences, secureStorage: secureStorage);
  }
}

AppSettings _customSettings({required String hfToken}) =>
    AppSettings.initial().copyWith(
      asrMode: ProcessingMode.cloud,
      summaryMode: ProcessingMode.cloud,
      whisperModelId: 'custom-whisper',
      gemmaModelId: 'custom-gemma',
      whisperThreads: 7,
      asrProvider: RemoteProviderId.openai,
      summaryProvider: RemoteProviderId.google,
      chatModelByProvider: {RemoteProviderId.google: 'chat-model'},
      asrModelByProvider: {RemoteProviderId.openai: 'asr-model'},
      autoDeleteAudio: true,
      summarizeEnabled: false,
      onboarded: true,
      hfToken: hfToken,
    );
