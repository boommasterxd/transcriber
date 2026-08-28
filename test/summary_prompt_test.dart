import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/summarization/summary_prompt.dart';

void main() {
  group('SummaryPrompt.parse', () {
    test('parses a clean JSON object', () {
      const raw =
          '{"title":"Berlin","gist":"Plan","points":["a","b"],"todos":["x"]}';
      final result = SummaryPrompt.parse(raw, fallbackTitle: 'fallback');
      expect(result.title, 'Berlin');
      expect(result.gist, 'Plan');
      expect(result.points, ['a', 'b']);
      expect(result.todos, ['x']);
    });

    test('extracts JSON wrapped in code fences and prose', () {
      const raw =
          'Here you go:\n```json\n{"title":"T","gist":"G","points":[],"todos":[]}\n```';
      final result = SummaryPrompt.parse(raw, fallbackTitle: 'fallback');
      expect(result.title, 'T');
      expect(result.gist, 'G');
      expect(result.points, isEmpty);
    });

    test('falls back gracefully when no JSON present', () {
      const raw = 'just plain text';
      final result = SummaryPrompt.parse(raw, fallbackTitle: 'My Title');
      expect(result.title, 'My Title');
      expect(result.gist, 'just plain text');
    });

    test('uses fallback title when title missing', () {
      const raw = '{"gist":"G","points":[],"todos":[]}';
      final result = SummaryPrompt.parse(raw, fallbackTitle: 'Fallback');
      expect(result.title, 'Fallback');
    });
  });
}
