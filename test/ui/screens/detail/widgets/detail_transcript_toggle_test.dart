import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/ui/screens/detail/widgets/detail_transcript_block.dart';

void main() {
  testWidgets('opens and closes the transcript with the keyboard', (
    tester,
  ) async {
    final strings = AppStrings.of(AppLanguage.en);
    var open = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.light, AppAccent.violet),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DetailTranscriptToggle.phone(
              strings: strings,
              isOpen: open,
              onTap: () => setState(() => open = !open),
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(open, isTrue);
    expect(find.text(strings.shHide), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(open, isFalse);
    expect(find.text(strings.shShow), findsOneWidget);
  });
}
