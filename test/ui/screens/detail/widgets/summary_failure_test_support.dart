import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/transcript_note.dart';

void expectSummaryFailure(TranscriptNote note, AppStrings strings) {
  expect(find.text(strings.summaryFailedTitle), findsOneWidget);
  expect(find.text(strings.summaryFailedBody), findsOneWidget);
  expect(find.text(note.summaryError!), findsOneWidget);
  if (note.gist.isNotEmpty) expect(find.text(note.gist), findsNothing);
  for (final text in [...note.points, ...note.todos.map((todo) => todo.text)]) {
    expect(find.text(text), findsNothing);
  }
  for (final label in [
    strings.shSummary,
    strings.shPoints,
    strings.shActions,
  ]) {
    expect(find.text(label.toUpperCase()), findsNothing);
  }
}
