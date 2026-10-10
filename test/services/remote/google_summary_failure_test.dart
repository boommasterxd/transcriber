import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

void main() {
  for (final parts in [
    <Map<String, String>>[],
    [
      {'text': '{"title":"Truncated'},
    ],
  ]) {
    test(
      'rejects token-limited summary with ${parts.length} text parts',
      () async {
        final httpClient = scriptedHttpClient([
          jsonResponse({
            'candidates': [
              {
                'finishReason': 'MAX_TOKENS',
                'content': {'parts': parts},
              },
            ],
          }),
        ]);
        final client = GoogleClient(apiKey: 'test-key', httpClient: httpClient);

        await expectLater(
          client.summarize(
            systemPrompt: 'system',
            userPrompt: 'user',
            modelId: 'gemini-3.5-flash-lite',
          ),
          throwsA(
            isA<RemoteApiException>().having(
              (error) => error.message,
              'message',
              'Gemini summary exceeded its response token limit.',
            ),
          ),
        );
        expect(httpClient.requests, hasLength(1));
      },
    );
  }
}
