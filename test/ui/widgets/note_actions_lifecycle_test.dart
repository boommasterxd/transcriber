import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/toast.dart';
import 'package:transcriber/ui/screens/detail/transcript_detail_screen.dart';

import '../screens/detail/detail_test_helpers.dart';

void main() {
  testWidgets('undo restores the note after the detail route has unmounted', (
    tester,
  ) async {
    final strings = AppStrings.of(AppLanguage.en);
    final note = detailTestNote();
    final notes = DetailTestNotesController([note]);
    await tester.pumpWidget(
      detailTestApp(
        notes: notes,
        withMessenger: true,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TranscriptDetailScreen(noteId: note.id),
                ),
              ),
              child: const Text('Open detail'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await confirmNoteDeletion(tester, strings);
    await tester.pumpAndSettle();
    expect(find.byType(TranscriptDetailScreen), findsNothing);
    expect(notes.state, isEmpty);

    await tester.tap(find.byType(SnackBarAction));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(notes.state.single.id, note.id);
    scaffoldMessengerKey.currentState?.clearSnackBars();
  });
}
