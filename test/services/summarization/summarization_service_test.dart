import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/summarization/summarization_service.dart';
import 'package:transcriber/services/summarization/summary_result.dart';

void main() {
  test(
    'summarization service contract receives transcript and language',
    () async {
      final service = _RecordingSummarizationService();
      const expected = SummaryResult(
        title: 'Title',
        gist: 'Gist',
        points: ['Point'],
        todos: ['Todo'],
      );
      service.result = expected;

      final result = await service.summarize('Transcript', german: true);

      expect(result, same(expected));
      expect(service.transcript, 'Transcript');
      expect(service.german, isTrue);
    },
  );

  test('service implementations can receive English requests', () async {
    final service = _RecordingSummarizationService();

    await service.summarize('English transcript', german: false);

    expect(service.transcript, 'English transcript');
    expect(service.german, isFalse);
  });
}

final class _RecordingSummarizationService implements SummarizationService {
  String? transcript;
  bool? german;
  SummaryResult result = const SummaryResult(
    title: '',
    gist: '',
    points: [],
    todos: [],
  );

  @override
  Future<SummaryResult> summarize(
    String transcript, {
    required bool german,
  }) async {
    this.transcript = transcript;
    this.german = german;
    return result;
  }
}
