import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/screens/share/widgets/share_result_body.dart';
import 'share_test_support.dart';
import '../detail/widgets/summary_failure_test_support.dart';

void main() {
  _registerSummaryToggleTest();
  _registerTranscriptOnlyTest();
  for (final gist in ['', 'Incomplete summary']) {
    _registerSummaryFailureTest(gist);
  }
}

void _registerSummaryFailureTest(String gist) {
  testWidgets('failed summary preview keeps accordion with gist "$gist"', (
    tester,
  ) async {
    final note = shareTestNote(
      gist: gist,
    ).copyWith(summaryError: '<Error> unavailable');
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
