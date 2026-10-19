import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/remote/openai_client.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/services/remote/remote_client_factory.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';

void main() {
  for (final provider in RemoteProviderId.values) {
    _registerLifecycleTests(provider);
  }
}

void _registerLifecycleTests(RemoteProviderId provider) {
  for (final failure in [false, true]) {
    test(
      '${provider.id} closes an owned transport after failure=$failure',
      () async {
        final transport = RecordingHttpClient(
          (_) async => jsonResponse({}, statusCode: failure ? 401 : 200),
        );
        final client = http.runWithClient(
          () => RemoteClientFactory.create(provider, 'test-key'),
          () => transport,
        );
        await _exerciseClient(client, failure: failure);
        client.close();
        client.close();
        expect(transport.closeCalls, 1);
      },
    );

    test(
      '${provider.id} retains an injected transport after failure=$failure',
      () async {
        final transport = RecordingHttpClient(
          (_) async => jsonResponse({}, statusCode: failure ? 401 : 200),
        );
        final client = provider == RemoteProviderId.openai
            ? OpenAiClient(apiKey: 'test-key', httpClient: transport)
            : GoogleClient(apiKey: 'test-key', httpClient: transport);
        await _exerciseClient(client, failure: failure);
        client.close();
        client.close();
        expect(transport.closeCalls, 0);
        transport.close();
        expect(transport.closeCalls, 1);
      },
    );
  }
}

Future<void> _exerciseClient(
  RemoteProviderClient client, {
  required bool failure,
}) async {
  if (failure) {
    await expectLater(
      client.testConnection(),
      throwsA(isA<RemoteApiException>()),
    );
  } else {
    await client.testConnection();
  }
}
