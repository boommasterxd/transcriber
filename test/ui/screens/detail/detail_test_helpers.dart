import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/core/toast.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/state/notes_controller.dart';
import 'package:transcriber/state/settings_controller.dart';

final class DetailTestNotesController extends NotesController {
  DetailTestNotesController(this.initialNotes);

  final List<TranscriptNote> initialNotes;
  final List<(String, int)> toggles = [];
  final List<String> deletions = [];

  @override
  List<TranscriptNote> build() => initialNotes;

  @override
  Future<void> toggleTodo(String noteId, int index) async {
    toggles.add((noteId, index));
    state = [
      for (final note in state)
        if (note.id == noteId)
          note.copyWith(
            todos: [
              for (var i = 0; i < note.todos.length; i++)
                TodoItem(
                  text: note.todos[i].text,
                  done: i == index ? !note.todos[i].done : note.todos[i].done,
                ),
            ],
          )
        else
          note,
    ];
  }

  @override
  Future<void> delete(String id) async {
    deletions.add(id);
    state = state.where((note) => note.id != id).toList();
  }

  @override
  Future<void> add(TranscriptNote note) async {
    state = [note, ...state];
  }
}

final class DetailTestSettingsController extends SettingsController {
  @override
  AppSettings build() => AppSettings.initial().copyWith(
    language: AppLanguage.en,
    accent: AppAccent.violet,
  );
}

final class TestMethodCallRecorder {
  final List<MethodCall> calls = [];

  MethodCall? callNamed(String method) {
    for (final call in calls.reversed) {
      if (call.method == method) return call;
    }
    return null;
  }
}

TestMethodCallRecorder recordMethodChannel(
  MethodChannel channel, {
  Object? result,
}) {
  final recorder = TestMethodCallRecorder();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        recorder.calls.add(call);
        return result;
      });
  addTearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  return recorder;
}

Future<void> useTestSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> cancelNoteDeletion(WidgetTester tester, AppStrings strings) async {
  await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
  await tester.pump();
  expect(find.text(strings.deleteNoteTitle), findsOneWidget);
  await tester.tap(find.text(strings.cancel));
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> confirmNoteDeletion(
  WidgetTester tester,
  AppStrings strings,
) async {
  await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
  await tester.pump();
  await tester.tap(find.text(strings.delete));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> verifyTranscriptCopy(
  WidgetTester tester,
  AppStrings strings,
  String expectedText,
  TestMethodCallRecorder clipboard,
) async {
  await tester.tap(find.text(strings.shCopy));
  await tester.pump();
  expect(
    (clipboard.callNamed('Clipboard.setData')?.arguments
        as Map<Object?, Object?>?)?['text'],
    expectedText,
  );
  expect(find.text(strings.shCopied), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 1601));
  expect(find.text(strings.shCopy), findsOneWidget);
}

TranscriptNote detailTestNote({
  String id = 'note-1',
  String gist = 'Concise summary',
  bool asrIsLocal = true,
  bool summaryIsLocal = false,
}) => TranscriptNote(
  id: id,
  title: 'Planning session',
  speaker: 'Alex',
  source: NoteSource.shared,
  durationSec: 65,
  createdAt: DateTime(2026, 8, 28),
  asrIsLocal: asrIsLocal,
  summaryIsLocal: summaryIsLocal,
  asrName: 'Whisper Base',
  asrSub: asrIsLocal ? 'On device' : 'Cloud ASR',
  llmName: 'Claude Sonnet',
  llmSub: summaryIsLocal ? 'On device' : 'Anthropic',
  gist: gist,
  points: const ['Confirm the launch plan'],
  todos: [TodoItem(text: 'Send the agenda')],
  transcript: const [
    TranscriptLine(time: '0:03', text: 'We should confirm the launch plan.'),
  ],
);

Widget detailTestApp({
  required DetailTestNotesController notes,
  required Widget home,
  bool withMessenger = false,
}) => ProviderScope(
  overrides: [
    notesControllerProvider.overrideWith(() => notes),
    settingsControllerProvider.overrideWith(DetailTestSettingsController.new),
  ],
  child: MaterialApp(
    scaffoldMessengerKey: withMessenger ? scaffoldMessengerKey : null,
    theme: AppTheme.build(Brightness.light, AppAccent.violet),
    home: home,
  ),
);
