import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
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
  testWidgets('search bar forwards entered text', (tester) async {
    String? query;
    final strings = AppStrings.of(AppLanguage.en);
    await tester.pumpWidget(
      wrapHomeWidget(
        HomeSearchBar(
          hint: strings.search,
          onChanged: (value) => query = value,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Weekly');

    expect(query, 'Weekly');
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
          isLocal: false,
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
      overrides: const TestNoteOverrides(isRemote: true, todoCount: 2),
    );
    await tester.pumpWidget(
      wrapHomeWidget(
        SizedBox(
          width: 320,
          child: Row(
            children: [
              Expanded(child: NoteModelBadge(note: note)),
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
            note: note,
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
  testWidgets('tablet history row reflects selection and handles taps', (
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
            note: note,
            strings: AppStrings.of(AppLanguage.en),
            selected: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    final row = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = row.decoration! as BoxDecoration;
    expect(decoration.color, AppPalette.light(AppAccent.blue).accentSoft);
    await tester.tap(find.text('Tablet note'));
    expect(tapped, isTrue);
  });
}
