import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/note_history.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/state/history_controller.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/home/widgets/history_page_controls.dart';
import 'package:transcriber/ui/screens/home/widgets/note_list_item.dart';
import 'package:transcriber/ui/screens/home/widgets/phone_home_view.dart';
import 'package:transcriber/ui/screens/home/widgets/tablet_sidebar.dart';

import '../../../support/note_test_fixtures.dart';
import '../../widgets/widget_test_helpers.dart';

void main() {
  _registerLazyHistoryTests();
  _registerPageControlTests();
  _registerSearchTest();
}

void _registerLazyHistoryTests() {
  for (final tablet in [false, true]) {
    testWidgets(
      'lazily mounts a 50-note page on ${tablet ? 'tablet' : 'phone'}',
      (tester) async {
        final controller = _HistoryFixture();
        await _pumpHistory(tester, controller, tablet: tablet);
        final rows = find.byType(tablet ? TabletHistoryRow : NoteListItem);
        final initialCount = rows.evaluate().length;
        expect(rows.evaluate().length, inExclusiveRange(0, 20));
        expect(find.text('History 49'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('History 49'),
          400,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 30,
        );
        expect(find.text('History 49'), findsOneWidget);
        expect(rows.evaluate().length, lessThan(20));
        debugPrint(
          '${tablet ? 'Tablet' : 'Phone'} mounted rows: '
          '$initialCount initially, ${rows.evaluate().length} at page end',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void _registerPageControlTests() {
  testWidgets('page controls expose labels and support keyboard pagination', (
    tester,
  ) async {
    final controller = _HistoryFixture();
    final semantics = tester.ensureSemantics();
    await _pumpControls(tester, controller);
    final strings = AppStrings.of(AppLanguage.en);
    expect(find.byTooltip(strings.previousPage), findsOneWidget);
    expect(find.byTooltip(strings.nextPage), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.nextCalls, 1);
    await tester.tap(find.byTooltip(strings.previousPage));
    await tester.pump();
    expect(controller.previousCalls, 1);
    semantics.dispose();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('loading disables navigation and retry recovers an error', (
    tester,
  ) async {
    final controller = _HistoryFixture();
    await _pumpControls(tester, controller);
    controller.loading();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    for (final button in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      expect(button.onPressed, isNull);
    }
    controller.fail();
    await tester.pump();
    final retry = AppStrings.of(AppLanguage.en).retry;
    expect(find.text(retry), findsOneWidget);
    await tester.tap(find.text(retry));
    await tester.pump();
    expect(controller.retryCalls, 1);
    expect(find.text(retry), findsNothing);
  });
}

void _registerSearchTest() {
  test('repository search finds a title beyond the first 1000 notes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(database);
    await repository.saveAll(List.generate(1001, _note));
    final first = await repository.loadHistoryPage();
    expect(first.entries, hasLength(50));
    expect(first.totalCount, 1001);
    expect(first.entries.any((note) => note.id == 'note-1000'), isFalse);
    final result = await repository.loadHistoryPage(query: 'History 1000');
    expect(result.entries.map((note) => note.id), ['note-1000']);
    expect(result.hasNext, isFalse);
  });
}

Future<void> _pumpHistory(
  WidgetTester tester,
  _HistoryFixture controller, {
  required bool tablet,
}) async {
  tester.view.physicalSize = tablet
      ? const Size(1000, 800)
      : const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final child = tablet
      ? Scaffold(
          body: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 360,
              child: TabletSidebar(
                selectedId: null,
                actions: TabletSidebarActions(
                  onQueryChanged: controller.search,
                  onSelect: (_) {},
                  onPickFile: () {},
                ),
              ),
            ),
          ),
        )
      : PhoneHomeView(onQueryChanged: controller.search, onPickFile: () {});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        historyControllerProvider.overrideWith(() => controller),
        stringsProvider.overrideWithValue(AppStrings.of(AppLanguage.en)),
        homeModelStatusProvider.overrideWithValue(
          const HomeModelStatus(label: 'Test model', warning: false),
        ),
      ],
      child: themed(child),
    ),
  );
  await tester.pump();
}

Future<void> _pumpControls(
  WidgetTester tester,
  _HistoryFixture controller,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [historyControllerProvider.overrideWith(() => controller)],
      child: themed(
        Scaffold(
          body: Consumer(
            builder: (context, ref, child) => HistoryPageControls(
              page: ref.watch(historyControllerProvider),
              strings: AppStrings.of(AppLanguage.en),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _HistoryFixture extends HistoryController {
  int nextCalls = 0;
  int previousCalls = 0;
  int retryCalls = 0;

  @override
  Future<HistoryPage> build() async => _page();

  @override
  Future<void> next() async {
    nextCalls++;
    state = AsyncData(_page(previous: true));
  }

  @override
  Future<void> previous() async {
    previousCalls++;
    state = AsyncData(_page());
  }

  @override
  void retry() {
    retryCalls++;
    state = AsyncData(_page());
  }

  void loading() => state = const AsyncLoading();
  void fail() =>
      state = AsyncError(StateError('Unavailable'), StackTrace.empty);
}

HistoryPage _page({bool previous = false}) => HistoryPage(
  entries: List.generate(50, (i) => NoteHistoryEntry.fromNote(_note(i))),
  hasNext: true,
  hasPrevious: previous,
  totalCount: 1001,
);

TranscriptNote _note(int index) => TranscriptNote(
  metadata: NoteMetadata(
    id: 'note-$index',
    title: 'History $index',
    speaker: 'Speaker',
    source: NoteSource.file,
    durationSec: 30,
    createdAt: DateTime.utc(2026, 1, 1).subtract(Duration(minutes: index)),
  ),
  content: NoteContent(
    gist: '',
    points: const [],
    todos: const [],
    transcript: [
      TranscriptLine(
        text: index == 1000 ? 'needle-in-transcript' : 'Synthetic transcript',
      ),
    ],
  ),
  origins: cloudNoteOrigins,
);
