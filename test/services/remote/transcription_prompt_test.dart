import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/remote/transcription_prompt.dart';

void main() {
  test('requests a plain transcript with automatic language detection', () {
    final prompt = buildTranscriptionPrompt('auto');

    expect(prompt, contains('verbatim'));
    expect(prompt, contains('only the transcript'));
    expect(prompt, isNot(contains('spoken language')));
  });

  test('adds an explicitly selected language', () {
    expect(buildTranscriptionPrompt('de'), contains('language is de'));
  });
}
