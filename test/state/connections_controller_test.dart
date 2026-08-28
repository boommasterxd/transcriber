import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/providers.dart';

import 'state_test_fakes.dart';

void main() {
  late ProviderContainer container;
  late FakeSettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = FakeSettingsRepository(await SharedPreferences.getInstance());
    container = ProviderContainer(
      overrides: [
        initialConnectionsProvider.overrideWithValue({
          RemoteProviderId.anthropic: true,
          RemoteProviderId.openai: false,
        }),
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() => container.dispose());

  test(
    'seeds connection state and reports unknown providers as disconnected',
    () {
      final controller = container.read(connectionsControllerProvider.notifier);

      expect(container.read(connectionsControllerProvider), {
        RemoteProviderId.anthropic: true,
        RemoteProviderId.openai: false,
      });
      expect(controller.isConnected(RemoteProviderId.anthropic), isTrue);
      expect(controller.isConnected(RemoteProviderId.google), isFalse);
    },
  );

  test('connect trims and stores a non-empty key', () async {
    final controller = container.read(connectionsControllerProvider.notifier);

    await controller.connect(RemoteProviderId.openai, '  openai-key  ');

    expect(repository.keys[RemoteProviderId.openai], 'openai-key');
    expect(controller.isConnected(RemoteProviderId.openai), isTrue);
  });

  test('ignores blank keys without changing state or persistence', () async {
    final controller = container.read(connectionsControllerProvider.notifier);

    await controller.connect(RemoteProviderId.openai, ' \n\t ');

    expect(repository.keys, isEmpty);
    expect(container.read(connectionsControllerProvider), {
      RemoteProviderId.anthropic: true,
      RemoteProviderId.openai: false,
    });
  });

  test(
    'disconnect removes the key and marks only that provider disconnected',
    () async {
      repository.keys[RemoteProviderId.anthropic] = 'anthropic-key';
      final controller = container.read(connectionsControllerProvider.notifier);

      await controller.disconnect(RemoteProviderId.anthropic);

      expect(repository.keys, isEmpty);
      expect(controller.isConnected(RemoteProviderId.anthropic), isFalse);
      expect(controller.isConnected(RemoteProviderId.openai), isFalse);
    },
  );

  test('returns an empty string when no API key exists', () async {
    final controller = container.read(connectionsControllerProvider.notifier);

    expect(await controller.apiKey(RemoteProviderId.google), isEmpty);

    repository.keys[RemoteProviderId.google] = 'google-key';
    expect(await controller.apiKey(RemoteProviderId.google), 'google-key');
  });
}
