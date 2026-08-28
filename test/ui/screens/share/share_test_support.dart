import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/transcript_note.dart';

import '../../../support/app_test_fakes.dart';

final shareTestStrings = AppStrings.of(AppLanguage.en);

ThemeData shareTestTheme() => ThemeData(
  extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.violet)],
);

TranscriptNote shareTestNote({
  required String gist,
  List<String> points = const ['First point'],
  List<TodoItem>? todos,
}) => TranscriptNote(
  id: 'share-note',
  title: 'Shared meeting',
  speaker: 'Speaker',
  source: NoteSource.shared,
  durationSec: 42,
  createdAt: DateTime.utc(2026),
  asrIsLocal: false,
  summaryIsLocal: false,
  asrName: 'gpt-transcribe',
  asrSub: 'OpenAI',
  llmName: 'gpt-5.6-luna',
  llmSub: 'OpenAI',
  gist: gist,
  points: points,
  todos: todos ?? [TodoItem(text: 'Follow up')],
  transcript: const [TranscriptLine(text: 'Transcript line')],
  audioPath: null,
);

AppSettings shareTestSettings() =>
    AppSettings.initial().copyWith(language: AppLanguage.en);

Widget shareTestChildApp({required Widget child}) {
  final database = testDatabase();
  addTearDown(database.close);
  return appScope(
    database: database,
    settings: shareTestSettings(),
    child: MaterialApp(
      theme: shareTestTheme(),
      home: Scaffold(body: child),
    ),
  );
}
