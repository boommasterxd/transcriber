import 'dart:convert';

import 'package:material_ui/material_ui.dart';
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
import 'package:transcriber/ui/widgets/todo_tile.dart';

import '../../../state/state_test_fakes.dart';
import '../../../support/app_test_fakes.dart';
import '../../../support/note_test_fixtures.dart';
import '../detail/detail_test_helpers.dart';
import '../detail/widgets/summary_failure_test_support.dart';

void main() {
  _registerUnknownSelectionTest();
  _registerNarrowLayoutTest();
  _registerWideNoteTest();
  _registerHeaderActionsTest();
  _registerSummaryFailureTest();
}

void _registerSummaryFailureTest() {
  testWidgets('tablet shows summary failure with expandable transcript', (
    tester,
  ) async {
    final note = _testNote().copyWith(summaryError: 'Summary unavailable');
    await _pumpPane(
      tester,
      size: const Size(1000, 1000),
      noteId: note.id,
      note: note,
    );
    final strings = AppStrings.of(AppLanguage.en);
    expectSummaryFailure(note, strings);
    expect(find.text('Tablet transcript'), findsNothing);
    await tester.tap(find.text(strings.shShow));
    await tester.pump();
    expect(find.text('Tablet transcript'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _registerUnknownSelectionTest() {
  testWidgets('renders no detail for an unknown selection', (tester) async {
    await _pumpPane(tester, size: const Size(900, 900), noteId: 'missing-note');

    expect(find.byType(CustomScrollView), findsNothing);
    expect(find.byType(PillButton), findsNothing);
    expect(find.text('Tablet test note'), findsNothing);
  });
}

void _registerNarrowLayoutTest() {
  testWidgets('narrow tablet pane supports todos, transcript and copying', (
    tester,
  ) async {
    final repository = await _pumpPane(
      tester,
      size: const Size(600, 1000),
      noteId: 'tablet-note',
    );
    final strings = AppStrings.of(AppLanguage.en);

    expect(find.text('Tablet todo'), findsOneWidget);
    expect(find.text(strings.shShow), findsOneWidget);

    await tester.tap(find.text('Tablet todo'));
    await tester.pump();
    expect(repository.loaded.single.todos.single.done, isTrue);

    await tester.tap(find.text(strings.shShow));
    await tester.pump();
    expect(find.text(strings.shHide), findsOneWidget);
    expect(find.text('Tablet transcript'), findsOneWidget);

    final clipboard = recordMethodChannel(const MethodChannel('app/clipboard'));
    await verifyTranscriptCopy(
      tester,
      strings,
      _testNote().fullTranscriptText,
      clipboard,
    );
  });
}

void _registerWideNoteTest() {
  testWidgets('wide tablet preserves two columns and recycles long task lists', (
    tester,
  ) async {
    final original = _testNote();
    final note = TranscriptNote(
      metadata: original.metadata,
      origins: original.origins,
      content: NoteContent(
        gist: original.gist,
        points: original.points,
        todos: List.generate(
          150,
          (index) => TodoItem(
            text: index % 3 == 1
                ? 'Tablet task ${index + 1}: ${'A longer task that wraps. ' * 5}'
                : 'Tablet task ${index + 1}',
          ),
        ),
        transcript: original.transcript,
      ),
    );
    final repository = await _pumpPane(
      tester,
      size: const Size(900, 800),
      noteId: note.id,
      note: note,
    );
    final strings = AppStrings.of(AppLanguage.en);
    final first = find.text('Tablet task 1');
    final last = find.text('Tablet task 150');
    final scroller = find.byType(Scrollable);

    expect(
      tester.getTopLeft(first).dx,
      greaterThan(tester.getTopRight(find.text(note.gist)).dx),
    );
    expect(last, findsNothing);
    await tester.scrollUntilVisible(last, 450, scrollable: scroller);
    expect(find.byType(TodoTile).evaluate().length, lessThan(40));
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(repository.loaded.single.todos.last.done, isTrue);

    final show = find.text(strings.shShow);
    await tester.ensureVisible(show);
    await tester.pumpAndSettle();
    await tester.tap(show);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(note.transcript.single.text),
      225,
      scrollable: scroller,
    );
    await tester.pumpAndSettle();
    expect(
      find.text(note.transcript.single.text).hitTestable(),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(first, -450, scrollable: scroller);
    await tester.pumpAndSettle();
    expect(first.hitTestable(), findsOneWidget);
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
    final arguments = shareCall!.arguments as Map<Object?, Object?>;
    expect(arguments['subject'], 'Tablet test note');
    final sharedText = arguments['text'] as String;
    const header = 'Transcriber-Provenance: ';
    final firstLine = sharedText.split('\n').first;
    expect(firstLine, startsWith(header));
    expect(jsonDecode(firstLine.substring(header.length)), {
      'version': 1,
      'summary': {
        'digitalSourceType': 'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia',
      },
    });
    expect(
      sharedText,
      contains('${strings.aiGeneratedSummary}\nTablet summary'),
    );
    expect(sharedText, endsWith(repository.loaded.single.fullTranscriptText));

    await cancelNoteDeletion(tester, strings);
    expect(repository.loaded, hasLength(1));

    await confirmNoteDeletion(tester, strings);
    expect(repository.loaded, isEmpty);
    expect(find.byType(CustomScrollView), findsNothing);
  });
}

Future<FakeNotesRepository> _pumpPane(
  WidgetTester tester, {
  required Size size,
  required String noteId,
  TranscriptNote? note,
}) async {
  await useTestSurface(tester, size);

  final database = testDatabase();
  addTearDown(database.close);
  note ??= _testNote();
  final repository = FakeNotesRepository(database)..loaded = [note];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        initialSettingsProvider.overrideWithValue(
          AppSettings.initial().copyWith(
            appearance: const AppearanceSettings(language: AppLanguage.en),
          ),
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
  metadata: NoteMetadata(
    id: 'tablet-note',
    title: 'Tablet test note',
    speaker: 'Tablet speaker',
    source: NoteSource.recording,
    durationSec: 65,
    createdAt: DateTime(2026, 8, 27),
  ),
  origins: cloudNoteOrigins,
  content: NoteContent(
    gist: 'Tablet summary',
    points: const ['Tablet key point'],
    todos: [TodoItem(text: 'Tablet todo')],
    transcript: const [TranscriptLine(text: 'Tablet transcript')],
  ),
);
