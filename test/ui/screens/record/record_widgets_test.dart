import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/ui/screens/record/widgets/record_body.dart';
import 'package:transcriber/ui/screens/record/widgets/record_controls.dart';
import 'package:transcriber/ui/screens/record/widgets/record_header.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.en);

  testWidgets('record header displays its title and handles closing', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      _themed(
        RecordHeader(title: strings.recTitle, onCancel: () => closed = true),
      ),
    );

    expect(find.text(strings.recTitle), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(closed, isTrue);
  });

  testWidgets('record status switches between recording and paused', (
    tester,
  ) async {
    await tester.pumpWidget(
      _themed(RecordStatusPill(paused: false, strings: strings)),
    );
    expect(find.text(strings.recording), findsOneWidget);

    await tester.pumpWidget(
      _themed(RecordStatusPill(paused: true, strings: strings)),
    );
    expect(find.text(strings.recPaused), findsOneWidget);
    expect(find.text(strings.recording), findsNothing);
  });

  testWidgets('record body shows the initial timer and privacy hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _themed(
        ProviderScope(
          child: Scaffold(body: RecordBody(paused: false, strings: strings)),
        ),
      ),
    );

    expect(find.text('0:00'), findsOneWidget);
    expect(find.text(strings.recHint), findsOneWidget);
  });

  testWidgets('record controls expose discard, stop and pause actions', (
    tester,
  ) async {
    var canceled = false;
    var stopped = false;
    var toggled = false;
    await tester.pumpWidget(
      _themed(
        RecordControls(
          paused: false,
          strings: strings,
          onCancel: () => canceled = true,
          onStop: () => stopped = true,
          onTogglePause: () => toggled = true,
        ),
      ),
    );

    expect(find.text(strings.recCancel), findsOneWidget);
    expect(find.text(strings.recStopShort), findsOneWidget);
    expect(find.text(strings.recPause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.tap(find.text(strings.recStopShort));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    expect(canceled, isTrue);
    expect(stopped, isTrue);
    expect(toggled, isTrue);

    await tester.pumpWidget(
      _themed(
        RecordControls(
          paused: true,
          strings: strings,
          onCancel: () {},
          onStop: () {},
          onTogglePause: () {},
        ),
      ),
    );
    expect(find.text(strings.recResume), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}

Widget _themed(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: <ThemeExtension<dynamic>>[AppPalette.light(AppAccent.violet)],
    ),
    home: child,
  );
}
