import 'package:test/test.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/services/summarization/remote_summarization_service.dart';
import 'package:transcriber/services/summarization/summarization_service.dart';

void main() {
  for (final response in ['', '  \n  ']) {
    test(
      'rejects an empty summary response: ${response.length} characters',
      () async {
        final service = RemoteSummarizationService(
          client: _RecordingSummaryClient(response: response),
          apiModelId: 'summary-model',
          fallbackTitle: 'Fallback',
        );

        await expectLater(
          service.summarize('Transcript', german: false),
          throwsA(
            isA<RemoteApiException>().having(
              (error) => error.message,
              'message',
              'The provider returned an empty summary.',
            ),
          ),
        );
      },
    );
  }
  test(
    'sends German prompts to the configured model and parses the response',
    () async {
      final client = _RecordingSummaryClient(
        response:
            '{"title":"Titel","gist":"Kernaussage","points":["Punkt"],"todos":["Aufgabe"]}',
      );
      final service = RemoteSummarizationService(
        client: client,
        apiModelId: 'summary-model',
        fallbackTitle: 'Fallback',
      );

      final result = await service.summarize(
        'Deutsches Transkript',
        german: true,
      );

      expect(service, isA<SummarizationService>());
      expect(result.title, 'Titel');
      expect(result.gist, 'Kernaussage');
      expect(result.points, ['Punkt']);
      expect(result.todos, ['Aufgabe']);
      expect(client.chatCalls, 1);
      expect(client.modelId, 'summary-model');
      expect(client.system, contains('Du bist ein präziser Assistent'));
      expect(client.user, contains('Deutsches Transkript'));
      expect(client.user, contains('Schreibe auf Deutsch'));
    },
  );

  test(
    'sends English prompts and applies the fallback for plain responses',
    () async {
      final client = _RecordingSummaryClient(
        response: '  Unstructured answer.  ',
      );
      final service = RemoteSummarizationService(
        client: client,
        apiModelId: 'english-model',
        fallbackTitle: 'Generated title',
      );

      final result = await service.summarize(
        'English transcript',
        german: false,
      );

      expect(result.title, 'Generated title');
      expect(result.gist, 'Unstructured answer.');
      expect(result.points, isEmpty);
      expect(result.todos, isEmpty);
      expect(client.system, contains('You are a precise assistant'));
      expect(client.user, contains('English transcript'));
      expect(client.user, contains('Write in English'));
      expect(client.user, isNot(contains('Schreibe auf Deutsch')));
    },
  );

  test('propagates failures from the remote client', () async {
    final error = StateError('provider unavailable');
    final client = _RecordingSummaryClient(error: error);
    final service = RemoteSummarizationService(
      client: client,
      apiModelId: 'summary-model',
      fallbackTitle: 'Fallback',
    );

    await expectLater(
      service.summarize('Transcript', german: false),
      throwsA(same(error)),
    );
    expect(client.chatCalls, 1);
  });
}

final class _RecordingSummaryClient implements SummaryProviderClient {
  _RecordingSummaryClient({this.response = '', this.error});

  final String response;
  final Object? error;
  int chatCalls = 0;
  String? system;
  String? user;
  String? modelId;

  @override
  Future<String> summarize({
    required String systemPrompt,
    required String userPrompt,
    required String modelId,
  }) async {
    chatCalls++;
    system = systemPrompt;
    user = userPrompt;
    this.modelId = modelId;
    if (error != null) throw error!;
    return response;
  }
}
