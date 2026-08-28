import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/ui/screens/detail/widgets/note_content_widgets.dart';
import 'package:transcriber/ui/screens/detail/widgets/note_summary_metadata_widgets.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.en);

  testWidgets('renders shared summary and note metadata', (tester) async {
    final note = _note();
    await tester.pumpWidget(
      _themed(
        ListView(
          children: [
            NoteSummaryCard(gist: note.gist, label: strings.shSummary),
            NoteMetadataChips(note: note, strings: strings),
          ],
        ),
      ),
    );

    expect(find.text(strings.shSummary.toUpperCase()), findsOneWidget);
    expect(find.text(note.gist), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    expect(
      find.text(strings.mSpkTemplate.replaceAll('{n}', '1')),
      findsOneWidget,
    );
    expect(find.text(strings.autoLang), findsOneWidget);
  });

  testWidgets('renders key points, todo count, and transcript rows', (
    tester,
  ) async {
    final note = _note();
    await tester.pumpWidget(
      _themed(
        ListView(
          children: [
            NoteKeyPoints(points: note.points),
            NoteTodoHeader(count: note.todos.length, label: strings.shActions),
            TranscriptRows(lines: note.transcript, bottomPadding: 14),
          ],
        ),
      ),
    );

    expect(find.text('First key point'), findsOneWidget);
    expect(find.text(strings.shActions.toUpperCase()), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0:03'), findsOneWidget);
    expect(find.text('Transcript text'), findsOneWidget);
  });

  testWidgets('renders empty note collections without placeholder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _themed(
        const Column(
          children: [
            NoteKeyPoints(points: []),
            TranscriptRows(lines: []),
          ],
        ),
      ),
    );

    expect(find.byType(Text), findsNothing);
  });
}

TranscriptNote _note() {
  return TranscriptNote(
    id: 'note-1',
    title: 'Test note',
    speaker: 'Speaker',
    source: NoteSource.shared,
    durationSec: 65,
    createdAt: DateTime(2026, 8, 28),
    asrIsLocal: false,
    summaryIsLocal: false,
    asrName: 'gpt-transcribe',
    asrSub: 'OpenAI',
    llmName: 'gemini-3.7-flash',
    llmSub: 'Google Gemini',
    gist: 'Compact summary',
    points: const ['First key point'],
    todos: [TodoItem(text: 'Follow up')],
    transcript: const [TranscriptLine(time: '0:03', text: 'Transcript text')],
  );
}

Widget _themed(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.violet)],
    ),
    home: Scaffold(body: child),
  );
}
