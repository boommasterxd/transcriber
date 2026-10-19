import 'dart:convert';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber/services/remote/openai_client.dart';
import 'package:transcriber/services/remote/provider_model_capabilities.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

const _documentedId = 'ft:gpt-4.1-nano-2025-04-14:openai::BTz2REMH';

void main() {
  _registerAllowedIds();
  _registerRejectedIds();
  test(
    'catalog preserves fine-tuned IDs and summary sends the full ID',
    () async {
      final httpClient = scriptedHttpClient([
        jsonResponse({
          'data': [
            {'id': _documentedId},
            {'id': 'ft:gpt-image-1:openai::AbCd1234'},
            {'id': 'ft:gpt-4.1-mini:openai:../unsafe:AbCd1234'},
            {'id': _documentedId},
          ],
        }),
        jsonResponse({
          'choices': [
            {
              'message': {'content': 'summary'},
            },
          ],
        }),
      ]);
      final client = OpenAiClient(apiKey: 'test-key', httpClient: httpClient);
      final models = await client.listModels(forTranscription: false);
      expect(models.map((model) => model.id), [_documentedId]);
      expect(
        await client.summarize(
          systemPrompt: 'system',
          userPrompt: 'user',
          modelId: models.single.id,
        ),
        'summary',
      );
      final request = httpClient.requests.last as http.Request;
      expect(request.url.path, '/v1/chat/completions');
      expect((jsonDecode(request.body) as Map)['model'], _documentedId);
    },
  );
}

void _registerAllowedIds() {
  for (final id in [
    _documentedId,
    'ft:gpt-4o-mini:openai:custom-model-name:7p4lURel',
    'ft:gpt-99-nova-2040-01-01:My_Org:transcribe-image-pro:AbCd1234',
    'ft:o99-mini:my-org::AbCd1234',
    'ft:gpt-99-nova:org:${'s' * 64}:AbCd1234',
    'ft:gpt-99-nova:org::${'A' * 180}',
  ]) {
    test('accepts fine-tuned summary based on its base model $id', () {
      expect(ProviderModelCapabilities.isOpenAiSummaryModel(id), isTrue);
      expect(ProviderModelCapabilities.isOpenAiTranscriptionModel(id), isFalse);
      expect(
        ProviderModelCapabilities.isGeminiSummaryModel(id, {'generateContent'}),
        isFalse,
      );
    });
  }
}

void _registerRejectedIds() {
  for (final id in [
    'ft:gpt-image-1:org::AbCd1234',
    'ft:gpt-99-audio:org:summary:AbCd1234',
    'ft:gpt-99-transcribe:org::AbCd1234',
    'ft:gpt-99-pro:org::AbCd1234',
    'ft:davinci-002:org::AbCd1234',
    'ft:GPT-99:org::AbCd1234',
    'ft:gpt--99:org::AbCd1234',
    'ft:gpt-99:org',
    'ft:gpt-99::suffix:AbCd1234',
    'ft:gpt-99:org:suffix:',
    'ft:gpt-99:org:suffix:AbCd1234:extra',
    'ft:gpt-99:org:../unsafe:AbCd1234',
    'ft:gpt-99/../../other:org::AbCd1234',
    'ft:gpt-99:org:%2Funsafe:AbCd1234',
    'ft:gpt-99:org:two words:AbCd1234',
    'ft:gpt-99:org:suffix:AbCd1234\n',
    'ft:gpt-99:org:suffix:AbCd1234\u0000',
    'ft:gpt-99-nova:org::${'A' * 181}',
  ]) {
    test('rejects unsafe or incompatible fine-tuned selection $id', () async {
      expect(ProviderModelCapabilities.isOpenAiSummaryModel(id), isFalse);
      final httpClient = scriptedHttpClient([]);
      final client = OpenAiClient(apiKey: 'test-key', httpClient: httpClient);
      await expectLater(
        client.summarize(
          systemPrompt: 'system',
          userPrompt: 'user',
          modelId: id,
        ),
        throwsA(isA<RemoteApiException>()),
      );
      expect(httpClient.requests, isEmpty);
    });
  }
}
