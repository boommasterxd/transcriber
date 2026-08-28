import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/ui/screens/tablet/tablet_detail_pane.dart';
import 'package:transcriber/ui/widgets/buttons.dart';

import '../../../state/state_test_fakes.dart';
import '../../../support/app_test_fakes.dart';
import '../detail/detail_test_helpers.dart';

void main() {
  _registerUnknownSelectionTest();
  _registerNarrowLayoutTest();
  _registerWideLayoutTest();
  _registerHeaderActionsTest();
}

void _registerUnknownSelectionTest() {
  testWidgets('renders no detail for an unknown selection', (tester) async {
    await _pumpPane(tester, size: const Size(900, 900), noteId: 'missing-note');

    expect(find.byType(ListView), findsNothing);
    expect(find.byType(PillButton), findsNothing);
    expect(find.text('Tablet test note'), findsNothing);
  });
}

void _registerNarrowLayoutTest() {
  testWidgets('uses a vertical layout on a narrow tablet pane', (tester) async {
    final repository = await _pumpPane(
      tester,
      size: const Size(600, 1000),
      noteId: 'tablet-note',
    );
    final strings = AppStrings.of(AppLanguage.en);

    final summaryY = tester.getTopLeft(find.text('Tablet summary')).dy;
    final pointY = tester.getTopLeft(find.text('Tablet key point')).dy;
    expect(pointY, greaterThan(summaryY));
    expect(find.text('Tablet todo'), findsOneWidget);
    expect(find.text(strings.shShow), findsOneWidget);

    await tester.tap(find.text('Tablet todo'));
    await tester.pump();
    expect(repository.loaded.single.todos.single.done, isTrue);

    await tester.tap(find.text(strings.shShow));
    await tester.pump();
    expect(find.text(strings.shHide), findsOneWidget);
    expect(find.text('Tablet transcript'), findsOneWidget);

    final clipboard = recordMethodChannel(SystemChannels.platform);
    await verifyTranscriptCopy(
      tester,
      strings,
      _testNote().fullTranscriptText,
      clipboard,
    );
  });
}

void _registerWideLayoutTest() {
  testWidgets('uses a two-column layout on a wide tablet pane', (tester) async {
    await _pumpPane(
      tester,
      size: const Size(1000, 1000),
      noteId: 'tablet-note',
    );

    final summaryY = tester.getTopLeft(find.text('Tablet summary')).dy;
    final pointY = tester.getTopLeft(find.text('Tablet key point')).dy;
    expect(pointY, lessThan(summaryY));
    expect(tester.takeException(), isNull);
  });
}

void _registerHeaderActionsTest() {
  testWidgets('shares content and requires confirmation before deletion', (
    tester,
  ) async {
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    final share = recordMethodChannel(shareChannel, result: 'success');
    final repository = await _pumpPane(
      tester,
      size: const Size(900, 900),
      noteId: 'tablet-note',
    );
    final strings = AppStrings.of(AppLanguage.en);

    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pump();
    final shareCall = share.callNamed('share');
    expect(shareCall?.method, 'share');
    expect(
      (shareCall?.arguments as Map<Object?, Object?>?)?['subject'],
      'Tablet test note',
    );

    await cancelNoteDeletion(tester, strings);
    expect(repository.loaded, hasLength(1));

    await confirmNoteDeletion(tester, strings);
    expect(repository.loaded, isEmpty);
    expect(find.byType(ListView), findsNothing);
  });
}

Future<FakeNotesRepository> _pumpPane(
  WidgetTester tester, {
  required Size size,
  required String noteId,
}) async {
  await useTestSurface(tester, size);

  final database = testDatabase();
  addTearDown(database.close);
  final note = _testNote();
  final repository = FakeNotesRepository(database)..loaded = [note];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        initialSettingsProvider.overrideWithValue(
          AppSettings.initial().copyWith(language: AppLanguage.en),
        ),
        initialConnectionsProvider.overrideWithValue(const {}),
        initialNotesProvider.overrideWithValue([note]),
        audioCacheManagerProvider.overrideWithValue(AudioCacheManager()),
        notesRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[
            AppPalette.light(AppAccent.violet),
          ],
        ),
        home: Scaffold(body: TabletDetailPane(noteId: noteId)),
      ),
    ),
  );
  await tester.pump();
  return repository;
}

TranscriptNote _testNote() => TranscriptNote(
  id: 'tablet-note',
  title: 'Tablet test note',
  speaker: 'Tablet speaker',
  source: NoteSource.recording,
  durationSec: 65,
  createdAt: DateTime(2026, 8, 27),
  asrIsLocal: false,
  summaryIsLocal: false,
  asrName: 'gpt-transcribe',
  asrSub: 'OpenAI',
  llmName: 'gemini-3.7-flash',
  llmSub: 'Google Gemini',
  gist: 'Tablet summary',
  points: const ['Tablet key point'],
  todos: [TodoItem(text: 'Tablet todo')],
  transcript: const [TranscriptLine(time: '0:03', text: 'Tablet transcript')],
);
