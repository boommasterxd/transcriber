import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/model_manager_controller.dart';
import 'package:transcriber/state/settings_controller.dart';

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
  asrIsLocal: true,
  summaryIsLocal: true,
  asrName: 'Whisper',
  asrSub: 'Base',
  llmName: 'Gemma',
  llmSub: 'Local',
  gist: gist,
  points: points,
  todos: todos ?? [TodoItem(text: 'Follow up')],
  transcript: const [TranscriptLine(time: '00:01', text: 'Transcript line')],
  audioPath: null,
);

final class ShareTestSettingsController extends SettingsController {
  @override
  AppSettings build() =>
      AppSettings.initial().copyWith(language: AppLanguage.en);
}

final class ShareTestConnectionsController extends ConnectionsController {
  @override
  Map<RemoteProviderId, bool> build() => {};
}

final class ShareTestModelManagerController extends ModelManagerController {
  @override
  ModelManagerState build() => const ModelManagerState();
}

Widget shareTestChildApp({required Widget child}) => ProviderScope(
  overrides: [
    settingsControllerProvider.overrideWith(ShareTestSettingsController.new),
  ],
  child: MaterialApp(
    theme: shareTestTheme(),
    home: Scaffold(body: child),
  ),
);
