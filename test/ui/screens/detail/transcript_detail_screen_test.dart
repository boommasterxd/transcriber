import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/ui/screens/detail/transcript_detail_screen.dart';
import 'package:transcriber/ui/widgets/todo_tile.dart';

import 'detail_test_helpers.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.en);

  _registerMissingNoteTest(strings);
  _registerSummaryTest(strings);
  _registerTranscriptOnlyTest(strings);
  _registerDeleteTest(strings);
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
    final clipboard = recordMethodChannel(SystemChannels.platform);

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

void _registerDeleteTest(AppStrings strings) {
  testWidgets('deletes without audio and restores the note with undo', (
    tester,
  ) async {
    final note = detailTestNote();
    final notes = DetailTestNotesController([note]);
    await tester.pumpWidget(
      detailTestApp(
        notes: notes,
        withMessenger: true,
        home: TranscriptDetailScreen(noteId: note.id),
      ),
    );

    await cancelNoteDeletion(tester, strings);
    expect(notes.deletions, isEmpty);

    await confirmNoteDeletion(tester, strings);
    expect(notes.deletions, [(id: note.id, deleteAudio: false)]);
    expect(find.text(strings.errorTitle), findsOneWidget);

    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    expect(find.text(note.title), findsOneWidget);
  });
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pump();
}
