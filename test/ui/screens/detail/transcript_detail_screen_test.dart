import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/state/notes_controller.dart';
import 'package:transcriber/ui/screens/detail/transcript_detail_screen.dart';
import 'package:transcriber/ui/widgets/todo_tile.dart';

import 'detail_test_helpers.dart';
import 'widgets/summary_failure_test_support.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.en);

  _registerMissingNoteTest(strings);
  _registerSummaryTest(strings);
  _registerTranscriptOnlyTest(strings);
  _registerLargeNoteTest(strings);
  for (final gist in ['', 'Incomplete summary']) {
    _registerSummaryFailureTest(strings, gist);
  }
  _registerDeleteTest(strings);
}

void _registerSummaryFailureTest(AppStrings strings, String gist) {
  testWidgets('preserves transcript after summary failure with gist "$gist"', (
    tester,
  ) async {
    await useTestSurface(tester, const Size(600, 1000));
    final note = detailTestNote(gist: gist)
        .copyWith(summaryError: '<Error> unavailable');
    await tester.pumpWidget(
      detailTestApp(
        notes: DetailTestNotesController([note]),
        home: TranscriptDetailScreen(noteId: note.id),
      ),
    );

    expectSummaryFailure(note, strings);
    expect(find.byType(TodoTile), findsNothing);
    expect(find.text(note.transcript.single.text), findsNothing);
    await _reveal(tester, find.text(strings.shShow));
    await tester.tap(find.text(strings.shShow));
    await tester.pump();
    await _reveal(tester, find.text(note.transcript.single.text));
    expect(find.text(note.transcript.single.text), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _registerMissingNoteTest(AppStrings strings) {
  testWidgets('shows an error state when the selected note is missing', (
    tester,
  ) async {
    final notes = DetailTestNotesController(const []);
    await tester.pumpWidget(
      detailTestApp(
        notes: notes,
        home: const TranscriptDetailScreen(noteId: 'missing'),
      ),
    );

    expect(find.text(strings.errorTitle), findsOneWidget);
    expect(find.byType(TranscriptDetailScreen), findsOneWidget);
  });
}

void _registerSummaryTest(AppStrings strings) {
  testWidgets('renders summary sections and supports todo and transcript', (
    tester,
  ) async {
    await useTestSurface(tester, const Size(600, 1000));
    final note = detailTestNote();
    final notes = DetailTestNotesController([note]);
    final clipboard = recordMethodChannel(const MethodChannel('app/clipboard'));

    await tester.pumpWidget(
      detailTestApp(
        notes: notes,
        withMessenger: true,
        home: TranscriptDetailScreen(noteId: note.id),
      ),
    );

    expect(find.text(note.gist), findsOneWidget);
    expect(find.text(strings.audioDelTitle), findsOneWidget);
    expect(find.text(note.transcript.single.text), findsNothing);
    await _reveal(tester, find.byType(TodoTile));
    await tester.tap(find.byType(TodoTile));
    await tester.pump(const Duration(milliseconds: 250));
    expect(notes.toggles, [(note.id, 0)]);
    expect(find.byKey(const ValueKey(true)), findsOneWidget);

    await _reveal(tester, find.text(strings.shShow));
    await tester.tap(find.text(strings.shShow));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text(strings.shHide), findsOneWidget);
    expect(find.text(note.transcript.single.text), findsOneWidget);
    await _reveal(tester, find.text(strings.shCopy));
    await verifyTranscriptCopy(
      tester,
      strings,
      note.fullTranscriptText,
      clipboard,
    );
  });
}

void _registerTranscriptOnlyTest(AppStrings strings) {
  testWidgets('shows transcript immediately when no summary exists', (
    tester,
  ) async {
    await useTestSurface(tester, const Size(600, 1000));
    final note = detailTestNote(gist: '');
    final notes = DetailTestNotesController([note]);
    await tester.pumpWidget(
      detailTestApp(
        notes: notes,
        home: TranscriptDetailScreen(noteId: note.id),
      ),
    );

    expect(find.text(strings.shShow), findsNothing);
    await _reveal(tester, find.text(note.transcript.single.text));
    expect(find.text(note.transcript.single.text), findsOneWidget);
    expect(find.text(strings.shSummary.toUpperCase()), findsNothing);
  });
}

void _registerLargeNoteTest(AppStrings strings) {
  testWidgets(
    'long phone note recycles rows and copies its complete transcript',
    (tester) async {
      await useTestSurface(tester, const Size(385, 720));
      final original = detailTestNote();
      final text =
          '${'Discuss this update and set clear next steps. ' * 190}End of transcript.';
      final note = TranscriptNote(
        metadata: original.metadata,
        origins: original.origins,
        content: NoteContent(
          gist: original.gist,
          points: List.generate(60, (index) => 'Subject ${index + 1}'),
          todos: List.generate(
            70,
            (index) => TodoItem(text: 'Task ${index + 1}'),
          ),
          transcript: [TranscriptLine(text: text)],
        ),
      );
      final notes = DetailTestNotesController([note]);
      final clipboard = recordMethodChannel(
        const MethodChannel('app/clipboard'),
      );
      await tester.pumpWidget(
        detailTestApp(
          notes: notes,
          withMessenger: true,
          home: TranscriptDetailScreen(noteId: note.id),
        ),
      );

      expect(find.text('Subject 60'), findsNothing);
      await _reveal(tester, find.text('Task 70'));
      expect(find.byType(TodoTile).evaluate().length, lessThan(40));
      await tester.tap(find.text('Task 70'));
      await tester.pumpAndSettle();
      expect(notes.toggles, [(note.id, 69)]);

      await _reveal(tester, find.text(strings.shShow));
      await tester.tap(find.text(strings.shShow));
      await tester.pump();
      expect(find.textContaining('End of transcript.'), findsNothing);
      await _reveal(tester, find.text(strings.shCopy));
      await verifyTranscriptCopy(tester, strings, text, clipboard);
      await _reveal(tester, find.textContaining('End of transcript.'));
      expect(find.textContaining('End of transcript.'), findsOneWidget);

      final scrollable = find.byType(Scrollable);
      await tester.scrollUntilVisible(
        find.text('Task 70'),
        -250,
        scrollable: scrollable,
      );
      expect(
        tester
            .widget<TodoTile>(
              find.ancestor(
                of: find.text('Task 70'),
                matching: find.byType(TodoTile),
              ),
            )
            .done,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

void _registerDeleteTest(AppStrings strings) {
  testWidgets('deletes without audio and restores the note with undo', (
    tester,
  ) async {
    final note = detailTestNote();
    final notes = DetailTestNotesController([note]);
    await tester.pumpWidget(
      detailTestApp(notes: notes, withMessenger: true, home: _noteListHome()),
    );

    await tester.tap(find.text(note.title));
    await tester.pumpAndSettle();

    await cancelNoteDeletion(tester, strings);
    expect(notes.deletions, isEmpty);

    await confirmNoteDeletion(tester, strings);
    expect(notes.deletions, [(id: note.id, deleteAudio: false)]);
    await tester.pumpAndSettle();
    expect(find.byType(TranscriptDetailScreen), findsNothing);
    expect(find.text(note.title), findsNothing);
    await tester.tap(find.text(strings.undo));
    await tester.pump();
    expect(find.text(note.title), findsOneWidget);
  });
}

Widget _noteListHome() => Consumer(
  builder: (context, ref, _) => Scaffold(
    body: Column(
      children: [
        for (final note in ref.watch(notesControllerProvider))
          TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => TranscriptDetailScreen(noteId: note.id),
              ),
            ),
            child: Text(note.title),
          ),
      ],
    ),
  ),
);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pump();
}
