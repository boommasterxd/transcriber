import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/remote/openai_client.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/services/remote/remote_client_factory.dart';

void main() {
  test('creates only the supported provider clients', () {
    final openai = RemoteClientFactory.create(
      RemoteProviderId.openai,
      'openai-key',
    );
    final google = RemoteClientFactory.create(
      RemoteProviderId.google,
      'google-key',
    );

    expect(openai, isA<OpenAiClient>());
    expect(google, isA<GoogleClient>());
    expect(openai, isA<TranscriptionProviderClient>());
    expect(openai, isA<SummaryProviderClient>());
    expect(openai, isA<ModelCatalogClient>());
    expect((openai as OpenAiClient).apiKey, 'openai-key');
    expect((google as GoogleClient).apiKey, 'google-key');
  });
}
