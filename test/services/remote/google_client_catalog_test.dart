import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

void main() {
  test('catalog-admitted new families pass the summary request guard', () async {
    const id = 'aurora-next-multimodal';
    final httpClient = scriptedHttpClient([
      jsonResponse({
        'models': [
          {
            'name': 'models/$id',
            'displayName': 'Aurora Next',
            'description':
                'General model with text and image input, audio transcription.',
            'supportedGenerationMethods': ['generateContent'],
          },
        ],
      }),
      jsonResponse({'candidates': []}),
    ]);
    final client = GoogleClient(apiKey: 'key', httpClient: httpClient);
    final model = (await client.listModels(forTranscription: false)).single;

    await client.summarize(
      systemPrompt: 'system',
      userPrompt: 'user',
      modelId: model.id,
    );

    expect(model.id, id);
    expect(
      httpClient.requests.last.url.path,
      '/v1beta/models/$id:generateContent',
    );
  });
  for (final token in [42, {}, [], 'x' * 2049]) {
    test('rejects malformed or oversized model page tokens $token', () async {
      await _expectPaginationFailure([token]);
    });
  }
  test('rejects repeated model page tokens', () async {
    await _expectPaginationFailure(['repeat', 'repeat']);
  });
  test('rejects unbounded model pages', () async {
    await _expectPaginationFailure(List.generate(10, (index) => 'page-$index'));
  });
  test('encodes provider page tokens as one query parameter', () async {
    const token = 'page?key=other&next=yes';
    final httpClient = scriptedHttpClient([
      jsonResponse({'models': [], 'nextPageToken': token}),
      jsonResponse({'models': []}),
    ]);
    final client = GoogleClient(apiKey: 'key', httpClient: httpClient);

    expect(await client.listModels(forTranscription: false), isEmpty);
    expect(httpClient.requests.last.url.queryParameters, {
      'pageSize': '1000',
      'pageToken': token,
    });
  });
}

Future<void> _expectPaginationFailure(List<Object?> tokens) async {
  final httpClient = scriptedHttpClient([
    for (final token in tokens)
      jsonResponse({'models': [], 'nextPageToken': token}),
  ]);
  final client = GoogleClient(apiKey: 'key', httpClient: httpClient);

  await expectLater(
    client.listModels(forTranscription: false),
    throwsA(isA<RemoteApiException>()),
  );
  expect(httpClient.requests, hasLength(tokens.length));
}
