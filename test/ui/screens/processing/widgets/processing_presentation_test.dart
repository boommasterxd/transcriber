import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/processing/processing_profile.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/state/processing_controller.dart';
import 'package:transcriber/ui/screens/processing/widgets/processing_error_view.dart';
import 'package:transcriber/ui/screens/processing/widgets/processing_status_content.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.en);
  const profile = ProcessingProfile(
    asr: StageInfo(name: 'Local ASR', sub: '75 MB', isLocal: true),
    summary: StageInfo(name: 'Cloud LLM', sub: 'Provider', isLocal: false),
  );

  _statusPresentationTests(strings, profile);
  _errorPresentationTests(strings);
}

void _statusPresentationTests(AppStrings strings, ProcessingProfile profile) {
  group('ProcessingStatusPresentation', () {
    test('preserves screen and share local status wording', () {
      const state = ProcessingState();

      final screen = ProcessingStatusPresentation.forScreen(
        strings: strings,
        state: state,
        profile: profile,
        summarizeEnabled: true,
      );
      final sheet = ProcessingStatusPresentation.forShareSheet(
        strings: strings,
        state: state,
        profile: profile,
        summarizeEnabled: true,
      );

      expect(screen.title, strings.shTranscribe);
      expect(screen.statusText, 'Local ASR · 75 MB');
      expect(sheet.statusText, '${strings.runningLocal} · Local ASR');
      expect(screen.isLocal, isTrue);
      expect(screen.showSteps, isTrue);
      expect(screen.activeStepIsSecond, isFalse);
    });

    test('selects the summary stage and rounds download progress', () {
      const state = ProcessingState(
        step: ProcessingStep.summarizing,
        modelProgress: 0.426,
      );

      final presentation = ProcessingStatusPresentation.forScreen(
        strings: strings,
        state: state,
        profile: profile,
        summarizeEnabled: false,
      );

      expect(presentation.title, strings.shSummarize);
      expect(presentation.statusText, '${strings.downloading} 43%');
      expect(presentation.isLocal, isFalse);
      expect(presentation.showSteps, isFalse);
      expect(presentation.activeStepIsSecond, isTrue);
    });
  });
}

void _errorPresentationTests(AppStrings strings) {
  group('ProcessingErrorPresentation', () {
    test('routes a missing model to settings', () {
      final presentation = ProcessingErrorPresentation.resolve(
        const ModelNotDownloadedException('internal detail'),
        strings,
      );

      expect(presentation.title, strings.modelMissingTitle);
      expect(presentation.body, strings.modelMissingBody);
      expect(presentation.actionLabel, strings.goToSettings);
      expect(presentation.isModelMissing, isTrue);
    });

    test('keeps other error text and routes to retry', () {
      final presentation = ProcessingErrorPresentation.resolve(
        const RemoteApiException('Provider unavailable'),
        strings,
      );

      expect(presentation.title, strings.errorTitle);
      expect(presentation.body, 'Provider unavailable');
      expect(presentation.actionLabel, strings.retry);
      expect(presentation.isModelMissing, isFalse);
    });

    test('selects the matching primary action', () {
      var retried = false;
      var openedSettings = false;
      final actions = ProcessingErrorActions(
        onRetry: () => retried = true,
        onClose: () {},
        onOpenSettings: () => openedSettings = true,
      );

      actions.actionFor(
        ProcessingErrorPresentation.resolve(
          const RemoteApiException('Retry'),
          strings,
        ),
      )();
      actions.actionFor(
        ProcessingErrorPresentation.resolve(
          const ModelNotDownloadedException('Settings'),
          strings,
        ),
      )();

      expect(retried, isTrue);
      expect(openedSettings, isTrue);
    });
  });
}
