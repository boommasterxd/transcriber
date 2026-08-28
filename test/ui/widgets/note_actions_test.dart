import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/toast.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/state/notes_controller.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/ui/widgets/note_actions.dart';

void main() {
  _registerConfirmationTests();
  _registerDeleteTest();
}

void _registerConfirmationTests() {
  testWidgets(
    'confirmDeleteNote returns true for delete and false for cancel',
    (tester) async {
      final strings = AppStrings.of(AppLanguage.en);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await confirmDeleteNote(context, strings);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(find.text(strings.deleteNoteTitle), findsOneWidget);
      expect(find.text(strings.deleteNoteBody), findsOneWidget);
      await tester.tap(find.text(strings.cancel));
      await tester.pump(const Duration(milliseconds: 200));
      expect(result, isFalse);

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.tap(find.text(strings.delete));
      await tester.pump(const Duration(milliseconds: 200));
      expect(result, isTrue);
    },
  );
}

void _registerDeleteTest() {
  testWidgets('deleteNoteWithUndo removes the note and restores it with undo', (
    tester,
  ) async {
    final strings = AppStrings.of(AppLanguage.en);
    final note = _note();
    SharedPreferences.setMockInitialValues({
      'notes': jsonEncode([note.toJson()]),
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(NotesRepository(prefs)),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) => Column(
                children: [
                  Text('${ref.watch(notesControllerProvider).length}'),
                  ElevatedButton(
                    onPressed: () => deleteNoteWithUndo(ref, note, strings),
                    child: const Text('Delete note'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Delete note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('0'), findsOneWidget);
    expect(find.text(strings.noteDeleted), findsOneWidget);

    await tester.tap(find.byType(SnackBarAction));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });
}

TranscriptNote _note() => TranscriptNote(
  id: 'widget-test-note',
  title: 'Test note',
  speaker: 'Test speaker',
  source: NoteSource.file,
  durationSec: 4,
  createdAt: DateTime(2024),
  asrIsLocal: true,
  summaryIsLocal: true,
  asrName: 'Local ASR',
  asrSub: 'Test',
  llmName: 'Local LLM',
  llmSub: 'Test',
  gist: 'Test gist',
  points: const [],
  todos: [],
  transcript: const [],
);
