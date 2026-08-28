import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/processing/processing_profile.dart';
import 'package:transcriber/state/processing_controller.dart';
import 'package:transcriber/ui/screens/processing/widgets/processing_status_content.dart';
import 'processing_widget_test_support.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.en);
  const profile = ProcessingProfile(
    asr: StageInfo(name: 'Whisper Base', sub: '75 MB', isLocal: true),
    summary: StageInfo(name: 'Cloud LLM', sub: 'Provider', isLocal: false),
  );

  testWidgets('shows transcription status, file name, and both steps', (
    tester,
  ) async {
    final presentation = ProcessingStatusPresentation.forScreen(
      strings: strings,
      state: const ProcessingState(),
      profile: profile,
      summarizeEnabled: true,
    );

    await tester.pumpWidget(
      buildProcessingTestApp(
        ProcessingStatusContent(
          presentation: presentation,
          strings: strings,
          fileName: 'meeting.m4a',
        ),
      ),
    );

    expect(find.text(strings.shTranscribe), findsOneWidget);
    expect(find.text('Whisper Base · 75 MB'), findsOneWidget);
    expect(find.text('meeting.m4a'), findsOneWidget);
    expect(find.text(strings.shStep1), findsOneWidget);
    expect(find.text(strings.shStep2), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('shows summary download progress and completed first step', (
    tester,
  ) async {
    final presentation = ProcessingStatusPresentation.forScreen(
      strings: strings,
      state: const ProcessingState(
        step: ProcessingStep.summarizing,
        modelProgress: 0.574,
      ),
      profile: profile,
      summarizeEnabled: true,
    );

    await tester.pumpWidget(
      buildProcessingTestApp(
        ProcessingStatusContent(presentation: presentation, strings: strings),
      ),
    );

    expect(find.text(strings.shSummarize), findsOneWidget);
    expect(find.text('${strings.downloading} 57%'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('does not render an empty file chip', (tester) async {
    final presentation = ProcessingStatusPresentation.forScreen(
      strings: strings,
      state: const ProcessingState(),
      profile: profile,
      summarizeEnabled: false,
    );

    await tester.pumpWidget(
      buildProcessingTestApp(
        ProcessingStatusContent(
          presentation: presentation,
          strings: strings,
          fileName: '',
        ),
      ),
    );

    expect(find.byIcon(Icons.insert_drive_file_outlined), findsNothing);
    expect(find.byType(Text), findsNWidgets(2));
  });
}
