import 'package:flutter/material.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/transcript_note.dart';

import '../../../support/note_test_fixtures.dart';

TranscriptNote buildTestNote({
  required String id,
  required String title,
  required DateTime createdAt,
  TestNoteOverrides overrides = const TestNoteOverrides(),
}) {
  return TranscriptNote(
    metadata: NoteMetadata(
      id: id,
      title: title,
      speaker: '',
      source: NoteSource.recording,
      durationSec: 30,
      createdAt: createdAt,
    ),
    origins: cloudNoteOrigins,
    content: NoteContent(
      gist: '',
      points: const [],
      todos: List.generate(
        overrides.todoCount,
        (index) => TodoItem(text: 'Task $index'),
      ),
      transcript: const [],
    ),
  );
}

class TestNoteOverrides {
  const TestNoteOverrides({this.todoCount = 0});

  final int todoCount;
}

Widget wrapHomeWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.blue)],
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

Widget captureBuildContext(ValueChanged<BuildContext> onBuild) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        onBuild(context);
        return const SizedBox();
      },
    ),
  );
}
