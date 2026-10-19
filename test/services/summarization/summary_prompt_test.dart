import 'package:test/test.dart';
import 'package:transcriber/services/summarization/summary_prompt.dart';

void main() {
  _registerSystemTests();
  _registerUserTests();
  _registerParseTests();
}

void _registerSystemTests() {
  group('SummaryPrompt.system', () {
    test('uses German instructions when requested', () {
      final prompt = SummaryPrompt.system(true);

      expect(prompt, contains('Du bist ein präziser Assistent'));
      expect(prompt, contains('gültigem JSON'));
      expect(prompt, isNot(contains('You are a precise assistant')));
    });

    test('uses English instructions when requested', () {
      final prompt = SummaryPrompt.system(false);

      expect(prompt, contains('You are a precise assistant'));
      expect(prompt, contains('valid JSON'));
      expect(prompt, isNot(contains('Du bist ein präziser Assistent')));
    });
  });
}

void _registerUserTests() {
  group('SummaryPrompt.user', () {
    test('builds a German structured-summary request', () {
      final prompt = SummaryPrompt.user(
        'Der Termin ist morgen um zehn Uhr.',
        german: true,
      );

      expect(
        prompt,
        contains('Fasse die folgende transkribierte Sprachnachricht'),
      );
      expect(prompt, contains('Schreibe auf Deutsch'));
      expect(prompt, contains('"title"'));
      expect(prompt, contains('"gist"'));
      expect(prompt, contains('"points"'));
      expect(prompt, contains('"todos"'));
      expect(prompt, contains('Der Termin ist morgen um zehn Uhr.'));
    });

    test('builds an English structured-summary request', () {
      final prompt = SummaryPrompt.user(
        'The appointment is tomorrow at ten.',
        german: false,
      );

      expect(
        prompt,
        contains('Summarize the following transcribed voice message'),
      );
      expect(prompt, contains('Write in English'));
      expect(prompt, contains('"title"'));
      expect(prompt, contains('"gist"'));
      expect(prompt, contains('The appointment is tomorrow at ten.'));
      expect(prompt, isNot(contains('Schreibe auf Deutsch')));
    });

    test(
      'preserves transcript content including whitespace and punctuation',
      () {
        const transcript =
            '  First line.\nSecond line: {keep this} / "quoted"  ';

        final prompt = SummaryPrompt.user(transcript, german: false);

        expect(prompt, contains(transcript));
        expect(prompt, contains('Transcript:\n"""'));
        expect(prompt, endsWith('"""'));
      },
    );
  });
}

void _registerParseTests() {
  group('SummaryPrompt.parse', () {
    _registerStructuredParseTests();
    _registerFallbackParseTests();
    _registerDefensiveParseTests();
  });
}

void _registerStructuredParseTests() {
  group('structured responses', () {
    test('maps every structured field from a JSON object', () {
      const raw =
          '{"title":" Berlin ","gist":" Main point ","points":[" one ","two"],"todos":[" call "]}';

      final result = SummaryPrompt.parse(raw, fallbackTitle: 'Fallback');

      expect(result.title, 'Berlin');
      expect(result.gist, 'Main point');
      expect(result.points, ['one', 'two']);
      expect(result.todos, ['call']);
    });

    test('extracts an object surrounded by prose and a code fence', () {
      _expectParsedSummary((
        raw:
            'Result:\n```json\n{"title":"T","gist":"G","points":[],"todos":[]}\n```\nDone',
        title: 'T',
        gist: 'G',
        points: const [],
        todos: const [],
      ));
    });

    test('trims list entries and ignores blank entries', () {
      const raw =
          '{"title":"T","gist":"G","points":[" first "," ","second"],"todos":["  do it  ","", "  "]}';

      final result = SummaryPrompt.parse(raw, fallbackTitle: 'Fallback');

      expect(result.points, ['first', 'second']);
      expect(result.todos, ['do it']);
    });

    test('converts non-string list entries to trimmed text', () {
      const raw = '{"title":"T","gist":"G","points":[1,true],"todos":[2.5]}';

      final result = SummaryPrompt.parse(raw, fallbackTitle: 'Fallback');

      expect(result.points, ['1', 'true']);
      expect(result.todos, ['2.5']);
    });

    test('uses fallback values when optional fields are missing or null', () {
      const raw = '{"title":" ","gist":null,"points":null,"todos":null}';

      final result = SummaryPrompt.parse(raw, fallbackTitle: 'Fallback');

      expect(result.title, 'Fallback');
      expect(result.gist, isEmpty);
      expect(result.points, isEmpty);
      expect(result.todos, isEmpty);
    });

    test('ignores list fields with non-list values', () {
      _expectParsedSummary((
        raw: '{"title":"T","gist":"G","points":"not a list","todos":false}',
        title: 'T',
        gist: 'G',
        points: const [],
        todos: const [],
      ));
    });
  });
}

void _registerFallbackParseTests() {
  group('fallback responses', () {
    test('falls back to trimmed raw text when JSON is absent', () {
      final result = SummaryPrompt.parse(
        '  The model returned plain text.  ',
        fallbackTitle: 'Fallback',
      );

      expect(result.title, 'Fallback');
      expect(result.gist, 'The model returned plain text.');
      expect(result.points, isEmpty);
      expect(result.todos, isEmpty);
    });

    test('falls back when the extracted object is malformed JSON', () {
      const raw = '  prefix {"title":"T", "gist": } suffix  ';

      final result = SummaryPrompt.parse(raw, fallbackTitle: 'Fallback');

      expect(result.title, 'Fallback');
      expect(result.gist, raw.trim());
      expect(result.points, isEmpty);
      expect(result.todos, isEmpty);
    });

    test('falls back when the JSON value is not an object', () {
      const raw = '["not", "an", "object"]';

      final result = SummaryPrompt.parse(raw, fallbackTitle: 'Fallback');

      expect(result.title, 'Fallback');
      expect(result.gist, raw);
    });

    test('handles a missing title while retaining other fields', () {
      const raw = '{"gist":"G","points":["P"],"todos":["A"]}';

      final result = SummaryPrompt.parse(raw, fallbackTitle: 'Fallback');

      expect(result.title, 'Fallback');
      expect(result.gist, 'G');
      expect(result.points, ['P']);
      expect(result.todos, ['A']);
    });
  });
}

void _expectParsedSummary(
  ({
    String raw,
    String title,
    String gist,
    List<String> points,
    List<String> todos,
  })
  expectation,
) {
  final result = SummaryPrompt.parse(
    expectation.raw,
    fallbackTitle: 'Fallback',
  );

  expect(result.title, expectation.title);
  expect(result.gist, expectation.gist);
  expect(result.points, expectation.points);
  expect(result.todos, expectation.todos);
}

void _registerDefensiveParseTests() {
  group('defensive parsing', () {
    test('uses fallback title when the title has a malformed scalar value', () {
      const raw = '{"title":42,"gist":"G","points":[],"todos":[]}';

      final result = SummaryPrompt.parse(raw, fallbackTitle: 'Fallback');

      expect(result.title, 'Fallback');
      expect(result.gist, 'G');
      expect(result.points, isEmpty);
      expect(result.todos, isEmpty);
    });

    test('uses an empty gist when the gist has a malformed scalar value', () {
      const raw = '{"title":"T","gist":true,"points":[],"todos":[]}';

      final result = SummaryPrompt.parse(raw, fallbackTitle: 'Fallback');

      expect(result.title, 'T');
      expect(result.gist, isEmpty);
      expect(result.points, isEmpty);
      expect(result.todos, isEmpty);
    });
  });
}
