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
  Object? error;

  Future<void> call(RemoteProviderId provider, String key) async {
    calls.add((provider, key));
    final failure = error;
    if (failure != null) throw failure;
  }
}
