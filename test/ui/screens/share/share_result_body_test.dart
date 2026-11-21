import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/ui/screens/share/widgets/share_result_body.dart';

import 'share_test_support.dart';
import '../detail/widgets/summary_failure_test_support.dart';

void main() {
  _registerSummaryToggleTest();
  _registerTranscriptOnlyTest();
  _registerLargePreviewTest();
  _registerSavingTest();
  for (final gist in ['', 'Incomplete summary']) {
    _registerSummaryFailureTest(gist);
  }
}

void _registerSummaryFailureTest(String gist) {
  testWidgets('failed summary preview keeps accordion with gist "$gist"', (
    tester,
  ) async {
    final note = shareTestNote(gist: gist)
        .copyWith(summaryError: '<Error> unavailable');
    await tester.pumpWidget(
      shareTestChildApp(
        child: ShareResultBody(
          note: note,
          saving: false,
          onClose: () {},
          onSave: () {},
        ),
      ),
    );

    expectSummaryFailure(note, shareTestStrings);
    expect(find.text('Transcript line'), findsNothing);
    await tester.scrollUntilVisible(
      find.text(shareTestStrings.shShow),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(shareTestStrings.shShow));
    await tester.pump();
    expect(find.text('Transcript line'), findsOneWidget);
    expect(find.text(shareTestStrings.shSave), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _registerSummaryToggleTest() {
  testWidgets('summary preview reveals and hides its transcript', (
    tester,
  ) async {
    final note = shareTestNote(gist: 'A concise summary.');
    await tester.pumpWidget(
      shareTestChildApp(
        child: ShareResultBody(
          note: note,
          saving: false,
          onClose: () {},
          onSave: () {},
        ),
      ),
    );

    expect(find.text(note.title), findsOneWidget);
    expect(find.text(note.gist), findsOneWidget);
    expect(find.text(shareTestStrings.shShow), findsOneWidget);
    expect(find.text('Transcript line'), findsNothing);

    await tester.tap(find.text(shareTestStrings.shShow));
    await tester.pump();
    expect(find.text(shareTestStrings.shHide), findsOneWidget);
    expect(find.text('Transcript line'), findsOneWidget);

    await tester.tap(find.text(shareTestStrings.shHide));
    await tester.pump();
    expect(find.text(shareTestStrings.shShow), findsOneWidget);
    expect(find.text('Transcript line'), findsNothing);
  });
}

void _registerTranscriptOnlyTest() {
  testWidgets('transcript-only preview shows transcript without toggle', (
    tester,
  ) async {
    final note = shareTestNote(gist: '', points: const [], todos: const []);
    await tester.pumpWidget(
      shareTestChildApp(
        child: ShareResultBody(
          note: note,
          saving: false,
          onClose: () {},
          onSave: () {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Transcript line'),
      250,
      maxScrolls: 4,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text(shareTestStrings.shTranscript.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text('Transcript line'), findsOneWidget);
    expect(find.text(shareTestStrings.shShow), findsNothing);
    expect(find.text(shareTestStrings.shHide), findsNothing);
  });
}

void _registerLargePreviewTest() {
  testWidgets('long share preview can scroll through all points and tasks', (
    tester,
  ) async {
    final note = shareTestNote(
      gist: 'A concise summary.',
      points: List.generate(80, (index) => 'Point ${index + 1}'),
      todos: List.generate(80, (index) => TodoItem(text: 'Task ${index + 1}')),
    );
    await tester.pumpWidget(
      shareTestChildApp(
        child: ShareResultBody(
          note: note,
          saving: false,
          onClose: () {},
          onSave: () {},
        ),
      ),
    );

    final scroller = find.byType(Scrollable);
    final lastPoint = find.text('Point 80');
    final lastTask = find.text('Task 80');
    expect(lastPoint, findsNothing);
    expect(lastTask, findsNothing);
    await tester.scrollUntilVisible(lastPoint, 450, scrollable: scroller);
    await tester.pumpAndSettle();
    expect(lastPoint.hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(lastTask, 450, scrollable: scroller);
    await tester.pumpAndSettle();
    expect(lastTask.hitTestable(), findsOneWidget);
    expect(find.text('Task 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _registerSavingTest() {
  testWidgets('share Save announces pending work and prevents activation', (
    tester,
  ) async {
    final note = shareTestNote(gist: '');
    var saving = false;
    var saves = 0;
    await tester.pumpWidget(
      shareTestChildApp(
        child: StatefulBuilder(
          builder: (context, setState) => ShareResultBody(
            note: note,
            saving: saving,
            onClose: () {},
            onSave: () => setState(() {
              saves++;
              saving = true;
            }),
          ),
        ),
      ),
    );

    await tester.tap(find.text(shareTestStrings.shSave));
    await tester.pump();
    final pending = find.bySemanticsLabel(shareTestStrings.shareSaving);
    expect(pending, findsOneWidget);
    final data = tester.getSemantics(pending).getSemanticsData();
    expect(data.flagsCollection.isLiveRegion, isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    await tester.tap(pending);
    expect(saves, 1);
  });
}
