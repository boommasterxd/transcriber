import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/note_history.dart';
import 'package:transcriber/ui/screens/home/widgets/active_model_pill.dart';
import 'package:transcriber/ui/screens/home/widgets/home_search_bar.dart';
import 'package:transcriber/ui/screens/home/widgets/note_badges.dart';
import 'package:transcriber/ui/screens/home/widgets/note_list_item.dart';
import 'package:transcriber/ui/screens/home/widgets/tablet_sidebar.dart';

import 'home_test_helpers.dart';

void main() {
  _registerSearchBarTest();
  _registerActiveModelPillTest();
  _registerNoteBadgesTest();
  _registerPhoneHistoryRowTest();
  _registerTabletHistoryRowTest();
}

void _registerSearchBarTest() {
  testWidgets('typing batches searches and keyboard submission is immediate', (
    tester,
  ) async {
    final queries = <String>[];
    final strings = AppStrings.of(AppLanguage.en);
    await tester.pumpWidget(
      wrapHomeWidget(
        HomeSearchBar(hint: strings.search, onChanged: queries.add),
      ),
    );

    final field = find.byType(TextField);
    await tester.enterText(field, 'We');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'Weekly');
    await tester.pump(const Duration(milliseconds: 100));
    expect(queries, isEmpty);

    await tester.pump(const Duration(milliseconds: 100));
    expect(queries, ['Weekly']);

    await tester.enterText(field, 'Weekly planning');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(queries, ['Weekly', 'Weekly planning']);
    await tester.pump(const Duration(milliseconds: 200));
    expect(queries, ['Weekly', 'Weekly planning']);
  });

  testWidgets('a completed search leaves newer typing intact', (tester) async {
    final searches = <String>[];
    var applied = '';
    late StateSetter update;
    await tester.pumpWidget(
      wrapHomeWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return HomeSearchBar(
              hint: 'Search',
              query: applied,
              onChanged: searches.add,
            );
          },
        ),
      ),
    );
    final field = find.byType(TextField);
    await tester.enterText(field, 'First');
    await tester.pump(const Duration(milliseconds: 180));
    expect(searches, ['First']);

    await tester.enterText(field, 'First and second');
    update(() => applied = 'First');
    await tester.pump();
    expect(find.text('First and second'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 180));
    expect(searches, ['First', 'First and second']);
  });
}

void _registerActiveModelPillTest() {
  testWidgets('active model pill exposes warning state and tap', (
    tester,
  ) async {
    var tapped = false;
    final strings = AppStrings.of(AppLanguage.en);
    await tester.pumpWidget(
      wrapHomeWidget(
        ActiveModelPill(
          label: 'Provider missing',
          activeText: strings.modelActive,
          warning: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('Provider missing'), findsOneWidget);
    expect(find.text(strings.modelActive), findsOneWidget);
    await tester.tap(find.text('Provider missing'));
    expect(tapped, isTrue);
  });
}

void _registerNoteBadgesTest() {
  testWidgets('note badges show model and localized todo count', (
    tester,
  ) async {
    final strings = AppStrings.of(AppLanguage.en);
    final note = buildTestNote(
      id: 'note',
      title: 'Planning',
      createdAt: DateTime(2026, 8, 28),
      overrides: const TestNoteOverrides(todoCount: 2),
    );
    await tester.pumpWidget(
      wrapHomeWidget(
        SizedBox(
          width: 320,
          child: Row(
            children: [
              Expanded(
                child: NoteModelBadge(note: NoteHistoryEntry.fromNote(note)),
              ),
              TodoCountBadge(count: note.todos.length, strings: strings),
            ],
          ),
        ),
      ),
    );

    expect(find.text(note.modelShort), findsOneWidget);
    expect(find.text(strings.todoLabel(2)), findsOneWidget);
  });
}

void _registerPhoneHistoryRowTest() {
  testWidgets('phone history row displays metadata and handles taps', (
    tester,
  ) async {
    var tapped = false;
    final strings = AppStrings.of(AppLanguage.en);
    final note = buildTestNote(
      id: 'phone',
      title: 'Phone note',
      createdAt: DateTime(2026, 8, 28),
    );
    await tester.pumpWidget(
      wrapHomeWidget(
        SizedBox(
          width: 400,
          child: NoteListItem(
            note: NoteHistoryEntry.fromNote(note),
            strings: strings,
            isLast: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Phone note'), findsOneWidget);
    expect(find.text(note.modelShort), findsOneWidget);
    await tester.tap(find.text('Phone note'));
    expect(tapped, isTrue);
  });
}

void _registerTabletHistoryRowTest() {
  testWidgets('tablet history row displays its title and handles taps', (
    tester,
  ) async {
    var tapped = false;
    final note = buildTestNote(
      id: 'tablet',
      title: 'Tablet note',
      createdAt: DateTime(2026, 8, 28),
    );
    await tester.pumpWidget(
      wrapHomeWidget(
        SizedBox(
          width: 344,
          child: TabletHistoryRow(
            note: NoteHistoryEntry.fromNote(note),
            strings: AppStrings.of(AppLanguage.en),
            selected: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tablet note'));
    expect(tapped, isTrue);
  });
}
