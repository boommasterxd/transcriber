import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/state/providers.dart';

import '../services/remote/http_test_client.dart';

void main() {
  for (final provider in RemoteProviderId.values) {
    for (final failure in [false, true]) {
      _registerCredentialLifecycle(provider, failure);
    }
  }
}

void _registerCredentialLifecycle(RemoteProviderId provider, bool failure) {
  test(
    '${provider.id} credential request closes transport on failure=$failure',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final client = RecordingHttpClient(
        (_) async => jsonResponse({}, statusCode: failure ? 401 : 200),
      );
      await http.runWithClient(() async {
        final tester = container.read(providerCredentialTesterProvider);
        final result = tester(provider, 'test-key');
        if (failure) {
          await expectLater(result, throwsA(isA<RemoteApiException>()));
        } else {
          await result;
        }
        expect(client.closeCalls, 1);
      }, () => client);
    },
  );
}
