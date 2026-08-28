import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/providers.dart';

import 'state_test_fakes.dart';

void main() {
  final fixture = _ConnectionsFixture();
  setUp(fixture.setUp);
  tearDown(fixture.tearDown);

  test('seeds both supported provider connection flags', () {
    final controller = fixture.controller;

    expect(fixture.connections, {
      RemoteProviderId.openai: true,
      RemoteProviderId.google: false,
    });
    expect(controller.isConnected(RemoteProviderId.openai), isTrue);
    expect(controller.isConnected(RemoteProviderId.google), isFalse);
  });

  for (final provider in RemoteProviderId.values) {
    test('validates and stores a trimmed ${provider.id} key', () async {
      fixture.tester.onTest = (testedProvider, key) {
        expect(fixture.repository.keys[testedProvider], isNull);
      };

      await fixture.controller.connect(provider, '  ${provider.id}-key  ');

      expect(fixture.tester.calls, [(provider, '${provider.id}-key')]);
      expect(fixture.repository.keys[provider], '${provider.id}-key');
      expect(fixture.controller.isConnected(provider), isTrue);
    });
  }

  test('rejects blank keys without testing or persisting', () async {
    await expectLater(
      fixture.controller.connect(RemoteProviderId.google, ' \n\t '),
      throwsArgumentError,
    );

    expect(fixture.tester.calls, isEmpty);
    expect(fixture.repository.keys, isEmpty);
    expect(fixture.connections[RemoteProviderId.google], isFalse);
  });

  test('does not replace a stored key when validation fails', () async {
    fixture.repository.keys[RemoteProviderId.openai] = 'stable-key';
    fixture.tester.error = StateError('invalid credentials');

    await expectLater(
      fixture.controller.connect(RemoteProviderId.openai, 'replacement'),
      throwsStateError,
    );

    expect(fixture.repository.keys[RemoteProviderId.openai], 'stable-key');
    expect(fixture.connections[RemoteProviderId.openai], isTrue);
  });

  test('replaces a stored key only after successful validation', () async {
    fixture.repository.keys[RemoteProviderId.openai] = 'old-key';

    await fixture.controller.connect(RemoteProviderId.openai, 'new-key');

    expect(fixture.repository.keys[RemoteProviderId.openai], 'new-key');
    expect(fixture.tester.calls, [(RemoteProviderId.openai, 'new-key')]);
  });

  test('tests the stored key without replacing it', () async {
    fixture.repository.keys[RemoteProviderId.google] = 'stored-key';

    await fixture.controller.test(RemoteProviderId.google);

    expect(fixture.tester.calls, [(RemoteProviderId.google, 'stored-key')]);
    expect(fixture.repository.keys[RemoteProviderId.google], 'stored-key');
  });

  test('cannot test a provider without a stored key', () async {
    await expectLater(
      fixture.controller.test(RemoteProviderId.google),
      throwsStateError,
    );
    expect(fixture.tester.calls, isEmpty);
  });

  test('disconnect removes only the selected provider key', () async {
    fixture.repository.keys.addAll({
      RemoteProviderId.openai: 'openai-key',
      RemoteProviderId.google: 'google-key',
    });

    await fixture.controller.disconnect(RemoteProviderId.openai);

    expect(fixture.repository.keys, {RemoteProviderId.google: 'google-key'});
    expect(fixture.controller.isConnected(RemoteProviderId.openai), isFalse);
    expect(fixture.controller.isConnected(RemoteProviderId.google), isFalse);
  });
}

final class _ConnectionsFixture {
  late AppDatabase database;
  late FakeSettingsRepository repository;
  late _CredentialTester tester;
  late ProviderContainer container;

  void setUp() {
    database = createTestDatabase();
    repository = FakeSettingsRepository(database);
    tester = _CredentialTester();
    container = ProviderContainer(
      overrides: [
        initialConnectionsProvider.overrideWithValue(const {
          RemoteProviderId.openai: true,
          RemoteProviderId.google: false,
        }),
        settingsRepositoryProvider.overrideWithValue(repository),
        providerCredentialTesterProvider.overrideWithValue(tester.call),
      ],
    );
  }

  ConnectionsController get controller =>
      container.read(connectionsControllerProvider.notifier);
  Map<RemoteProviderId, bool> get connections =>
      container.read(connectionsControllerProvider);

  Future<void> tearDown() async {
    container.dispose();
    await database.close();
  }
}

final class _CredentialTester {
  final List<(RemoteProviderId, String)> calls = [];
  void Function(RemoteProviderId provider, String key)? onTest;
  Object? error;

  Future<void> call(RemoteProviderId provider, String key) async {
    calls.add((provider, key));
    onTest?.call(provider, key);
    final failure = error;
    if (failure != null) throw failure;
  }
}
