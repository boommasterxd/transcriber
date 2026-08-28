import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/ui/screens/detail/widgets/audio_deleted_notice.dart';
import 'package:transcriber/ui/screens/detail/widgets/detail_header.dart';
import 'package:transcriber/ui/screens/detail/widgets/detail_transcript_block.dart';
import 'package:transcriber/ui/screens/detail/widgets/processed_with_card.dart';

import '../detail_test_helpers.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.en);

  _registerHeaderTest(strings);
  _registerTranscriptTest(strings);
  _registerTranscriptVariantsTest(strings);
  _registerNoticeTest(strings);
  _registerProcessedWithTest(strings);
}

void _registerHeaderTest(AppStrings strings) {
  testWidgets('detail header renders metadata and dispatches every action', (
    tester,
  ) async {
    var backCount = 0;
    var shareCount = 0;
    var deleteCount = 0;
    final note = detailTestNote();
    await tester.pumpWidget(
      _wrap(
        DetailHeader(
          note: note,
          strings: strings,
          actions: DetailHeaderActions(
            onBack: () => backCount++,
            onShare: () => shareCount++,
            onDelete: () => deleteCount++,
          ),
        ),
      ),
    );

    expect(find.text(note.title), findsOneWidget);
    expect(find.textContaining(note.speaker), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    expect((backCount, deleteCount, shareCount), (1, 1, 1));
  });
}

void _registerTranscriptTest(AppStrings strings) {
  testWidgets('transcript block shows state and dispatches copy and share', (
    tester,
  ) async {
    var copyCount = 0;
    var shareCount = 0;
    final note = detailTestNote();
    await tester.pumpWidget(
      _wrap(
        DetailTranscriptBlock(
          note: note,
          strings: strings,
          copied: false,
          actions: DetailTranscriptActions(
            onCopy: () => copyCount++,
            onShare: () => shareCount++,
          ),
        ),
      ),
    );

    expect(find.text(strings.shTranscript.toUpperCase()), findsOneWidget);
    expect(find.text(note.transcript.single.text), findsOneWidget);
    expect(find.text(strings.shCopy), findsOneWidget);
    await tester.tap(find.text(strings.shCopy));
    await tester.tap(find.text(strings.shShare));
    expect((copyCount, shareCount), (1, 1));

    await tester.pumpWidget(
      _wrap(
        DetailTranscriptBlock(
          note: note,
          strings: strings,
          copied: true,
          actions: const DetailTranscriptActions(onCopy: _noOp, onShare: _noOp),
        ),
      ),
    );
    expect(find.text(strings.shCopied), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}

void _registerTranscriptVariantsTest(AppStrings strings) {
  testWidgets('supports copy-only transcript and both toggle styles', (
    tester,
  ) async {
    var tapCount = 0;
    final note = detailTestNote();
    await tester.pumpWidget(
      _wrap(
        ListView(
          children: [
            DetailTranscriptBlock(
              note: note,
              strings: strings,
              copied: false,
              style: const DetailTranscriptStyle(
                rowBottomPadding: 4,
                rowFontSize: 13,
              ),
              actions: DetailTranscriptActions(onCopy: () => tapCount++),
            ),
            DetailTranscriptToggle.phone(
              strings: strings,
              isOpen: true,
              onTap: () => tapCount++,
            ),
            DetailTranscriptToggle.phone(
              strings: strings,
              isOpen: false,
              onTap: _noOp,
            ),
            DetailTranscriptToggle.tablet(
              strings: strings,
              isOpen: false,
              onTap: _noOp,
            ),
          ],
        ),
      ),
    );

    expect(find.text(strings.shShare), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    await tester.tap(find.text(strings.shCopy));
    await tester.tap(find.text(strings.shHide));
    expect(tapCount, 2);
  });
}

void _registerNoticeTest(AppStrings strings) {
  testWidgets('audio deletion notice explains the missing source audio', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(AudioDeletedNotice(strings: strings)));

    expect(find.text(strings.audioDelTitle), findsOneWidget);
    expect(find.text(strings.audioDelSub), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
  });
}

void _registerProcessedWithTest(AppStrings strings) {
  testWidgets('processed card distinguishes local and cloud stages', (
    tester,
  ) async {
    final note = detailTestNote(asrIsLocal: true, summaryIsLocal: false);
    await tester.pumpWidget(
      _wrap(ProcessedWithCard(note: note, strings: strings)),
    );

    expect(find.text(strings.shStep1), findsOneWidget);
    expect(find.text(strings.shStep2), findsOneWidget);
    expect(find.text(note.asrName), findsOneWidget);
    expect(find.text(note.llmName), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
  });
}

void _noOp() {}

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.build(Brightness.light, AppAccent.violet),
  home: Scaffold(body: child),
);
