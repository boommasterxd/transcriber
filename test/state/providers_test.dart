import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/models/local_model_runtime.dart';
import 'package:transcriber/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _registerBootstrapTests();
  _registerRepositoryTest();
  _registerServiceTest();
}

void _registerBootstrapTests() {
  test('required bootstrap providers fail without explicit overrides', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => container.read(sharedPreferencesProvider), _missingOverride);
    expect(() => container.read(initialSettingsProvider), _missingOverride);
    expect(() => container.read(initialConnectionsProvider), _missingOverride);
  });

  test('bootstrap values preserve settings and connection flags', () {
    final settings = AppSettings.initial();
    const connections = {RemoteProviderId.google: true};
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(settings),
        initialConnectionsProvider.overrideWithValue(connections),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(initialSettingsProvider), same(settings));
    expect(container.read(initialConnectionsProvider), same(connections));
  });
}

void _registerRepositoryTest() {
  test(
    'repository providers share the overridden preferences instance',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      await container.read(notesRepositoryProvider).saveAll(const []);

      expect(preferences.getString('notes'), '[]');
      expect(
        container.read(settingsRepositoryProvider),
        same(container.read(settingsRepositoryProvider)),
      );
    },
  );
}

void _registerServiceTest() {
  test(
    'simple service providers cache values until container disposal',
    () async {
      final recorderCalls = <MethodCall>[];
      final recorderDisposed = Completer<void>();
      const recorderChannel = MethodChannel('com.llfbandit.record/messages');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(recorderChannel, (call) async {
            recorderCalls.add(call);
            if (call.method == 'dispose') recorderDisposed.complete();
            return null;
          });
      final container = ProviderContainer();
      final firstModelRuntime = container.read(localModelRuntimeProvider);
      final firstPipeline = container.read(processingPipelineProvider);
      final firstRecorder = container.read(audioRecorderProvider);
      final firstShareService = container.read(shareIntentServiceProvider);

      expect(firstModelRuntime, isA<EngineLocalModelRuntime>());
      expect(
        container.read(localModelRuntimeProvider),
        same(firstModelRuntime),
      );
      expect(container.read(processingPipelineProvider), same(firstPipeline));
      expect(container.read(audioRecorderProvider), same(firstRecorder));
      expect(
        container.read(shareIntentServiceProvider),
        same(firstShareService),
      );

      container.dispose();
      await recorderDisposed.future;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(recorderChannel, null);

      expect(recorderCalls.map((call) => call.method), contains('dispose'));
    },
  );
}

final _missingOverride = throwsA(
  predicate<Object>((error) => error.toString().contains('must be overridden')),
);
