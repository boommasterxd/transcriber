import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/ui/screens/detail/widgets/detail_transcript_block.dart';
import 'package:transcriber/ui/screens/detail/widgets/note_content_widgets.dart';
import 'package:transcriber/ui/screens/detail/widgets/note_summary_metadata_widgets.dart';

import '../../../../support/note_test_fixtures.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.en);

  testWidgets('renders shared summary and note metadata', (tester) async {
    final note = _note();
    await tester.pumpWidget(
      _themed(
        ListView(
          children: [
            NoteSummaryCard(note: note, strings: strings),
            NoteMetadataChips(note: note, strings: strings),
          ],
        ),
      ),
    );

    expect(find.text(strings.aiGeneratedSummary.toUpperCase()), findsOneWidget);
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
        CustomScrollView(
          slivers: [
            NoteKeyPoints(points: note.points, label: strings.shPoints),
            NoteTodos.preview(todos: note.todos, strings: strings),
            TranscriptRows(lines: note.transcript, bottomPadding: 14),
          ],
        ),
      ),
    );

    expect(find.text('First key point'), findsOneWidget);
    expect(find.text(strings.shActions.toUpperCase()), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0:03'), findsNothing);
    expect(find.text('Transcript text'), findsOneWidget);
  });

  testWidgets('renders an empty transcript without placeholder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _themed(const CustomScrollView(slivers: [TranscriptRows(lines: [])])),
    );

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('splits long transcript display only at complete characters', (
    tester,
  ) async {
    final spansCluster = '${'x' * 639}👩🏽‍💻suffix';
    final keepsWord = '${'a' * 500} ${'b' * 150}';
    await tester.pumpWidget(
      _themed(
        CustomScrollView(
          slivers: [
            TranscriptRows(
              lines: [
                TranscriptLine(text: spansCluster),
                TranscriptLine(text: keepsWord),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('${'x' * 639}👩🏽‍💻'), findsOneWidget);
    expect(find.text('suffix'), findsOneWidget);
    expect(find.text('${'a' * 500} '), findsOneWidget);
    expect(find.text('b' * 150), findsOneWidget);
  });
}

TranscriptNote _note() {
  return TranscriptNote(
    metadata: NoteMetadata(
      id: 'note-1',
      title: 'Test note',
      speaker: 'Speaker',
      source: NoteSource.shared,
      durationSec: 65,
      createdAt: DateTime(2026, 8, 28),
    ),
    origins: cloudNoteOrigins,
    content: NoteContent(
      gist: 'Compact summary',
      points: const ['First key point'],
      todos: [TodoItem(text: 'Follow up')],
      transcript: const [TranscriptLine(text: 'Transcript text')],
    ),
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
